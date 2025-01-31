import boto3
import pickle
import argparse
import sys
import os
import copy
import subprocess
from typing import Optional
from pathlib import Path
from string import Template


def run_terraform_fmt():
    try:
        result = subprocess.run(
            ["terraform", "fmt", "-recursive"],
            check=True,
            capture_output=True,
            text=True,
        )

        if result.stdout:
            print(result.stdout)

    except subprocess.CalledProcessError as e:
        print(f"Error running terraform fmt: {e.stderr}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(
            "Error: terraform command not found. Please ensure Terraform is installed and in your PATH",
            file=sys.stderr,
        )
        sys.exit(1)


def get_provisioned_product_by_account_id(account_id):
    sc_client = boto3.client("servicecatalog")
    response = sc_client.search_provisioned_products(
        Filters={"SearchQuery": [f"physicalId:{account_id}"]}
    )

    if response["ProvisionedProducts"]:
        product = response["ProvisionedProducts"][0]
        return product["Id"]

    return None


def get_provisioned_product_by_account_name(account_name):
    sc_client = boto3.client("servicecatalog")
    try:
        provisioned_name = f"{account_name}"

        response = sc_client.search_provisioned_products(
            Filters={"SearchQuery": [f"name:{provisioned_name}"]}
        )

        if response["ProvisionedProducts"]:
            product = response["ProvisionedProducts"][0]
            return product["Id"]
        return None

    except sc_client.exceptions.ResourceNotFoundException:
        return None


def get_admin_policy_arn() -> Optional[str]:
    """Get the ARN of the AWSControlTowerAdminPolicy."""
    try:
        iam = boto3.client("iam")
        response = iam.list_policies(Scope="All")
        for policy in response.get("Policies", []):
            if policy["PolicyName"] == "AWSControlTowerAdminPolicy":
                return policy["Arn"]
        return None
    except ClientError as e:
        print(f"Error fetching admin policy ARN: {e}")
        return None


def get_cloudtrail_policy_arn() -> Optional[str]:
    """Get the ARN of the AWSControlTowerCloudTrailRolePolicy."""
    try:
        iam = boto3.client("iam")
        response = iam.list_policies(Scope="All")
        for policy in response.get("Policies", []):
            if policy["PolicyName"] == "AWSControlTowerCloudTrailRolePolicy":
                return policy["Arn"]
        return None
    except ClientError as e:
        print(f"Error fetching CloudTrail policy ARN: {e}")
        return None


def get_stackset_policy_arn() -> Optional[str]:
    """Get the ARN of the AWSControlTowerStackSetRolePolicy."""
    try:
        iam = boto3.client("iam")
        response = iam.list_policies(Scope="All")
        for policy in response.get("Policies", []):
            if policy["PolicyName"] == "AWSControlTowerStackSetRolePolicy":
                return policy["Arn"]
        return None
    except ClientError as e:
        print(f"Error fetching StackSet policy ARN: {e}")
        return None


def get_kms_key_id() -> Optional[str]:
    """Get the KMS key ID for the control tower key."""
    try:
        kms = boto3.client("kms")
        response = kms.list_aliases()
        for alias in response.get("Aliases", []):
            if alias["AliasName"] == "alias/control_tower_key":
                return alias["TargetKeyId"]
        return None
    except ClientError as e:
        print(f"Error fetching KMS key ID: {e}")
        return None


def get_landing_zone_arn() -> Optional[str]:
    """Get the Control Tower landing zone ARN."""
    try:
        ct = boto3.client("controltower")
        response = ct.list_landing_zones()
        landing_zones = response.get("landingZones", [])
        if landing_zones:
            return landing_zones[0]["arn"]
        return None
    except ClientError as e:
        print(f"Error fetching landing zone ARN: {e}")
        return None


def get_organization_id(profile_name):
    try:
        session = boto3.session.Session(profile_name=profile_name)
        org = session.client("organizations")

        response = org.describe_organization()
        org_id = response["Organization"]["Id"]

        return org_id
    except Exception as e:
        print(f"Error getting organization ID: {str(e)}", file=sys.stderr)
        sys.exit(1)


def list_accounts(profile_name):
    session = boto3.session.Session(profile_name=profile_name)
    client = session.client("sts")
    org = session.client("organizations")

    paginator = org.get_paginator("list_accounts")
    page_iterator = paginator.paginate()

    accounts = []

    for page in page_iterator:
        for account in page["Accounts"]:
            response = org.list_tags_for_resource(ResourceId=account["Id"])
            account["Tags"] = response.get("Tags", [])

            try:
                account_details = org.describe_account(AccountId=account["Id"])
                account["IamUserAccessToBilling"] = account_details.get(
                    "Account", {}
                ).get("IamUserAccessToBilling", "ALLOW")
            except org.exceptions.AccountNotFoundException:
                print(f"Warning: Could not find account details for {account['Id']}")
                account["IamUserAccessToBilling"] = "ALLOW"

            accounts.append(account)

    return sorted(accounts, key=lambda k: k["Name"])


def generate_org_imports(import_prefix, org_id):
    imports = [
        f"""import {{
  to = {import_prefix}.module.organization.aws_organizations_organization.root[0]
  id = "{org_id}"
        }}"""
    ]
    return "\n\n".join(imports)


def generate_ct_account_imports(import_prefix, accounts, account_to_pp):
    imports = [""]
    for account in accounts:
        account_id = account["Id"]
        account_key = account["Name"]
        pp_id = account_to_pp.get(account_id)
        import_block = f"""import {{
  # {account_key} - {account_id}
  to = {import_prefix}.module.accounts.controltower_aws_account.account["{account_key}"]
  id = "{pp_id}"
}}"""
        imports.append(import_block)
    return "\n\n".join(imports)


def parse_accounts(accounts):
    ret_accounts = []
    for a in accounts:
        account = copy.deepcopy(a)
        account_key = account["Name"]
        if account_key == "Audit":
            account["is_audit_account"] = True
        if account_key == "Log archive":
            account["is_logs_account"] = True
        if account["IamUserAccessToBilling"] == "ALLOW":
            account["iam_user_access_to_billing"] = "true"
        else:
            account["iam_user_access_to_billing"] = "false"
        ret_accounts.append(account)
    return ret_accounts


def generate_child_accounts_var(accounts):
    var_lines = ["locals {", "child_accounts = {"]

    for account in accounts:
        account_key = account["Name"]
        var_lines.append(f'  "{account_key}" = {{')
        var_lines.append(f'    email = "{account["Email"]}"')
        if account.get("is_audit_account"):
            var_lines.append("    is_audit_account = true")
        if account.get("is_logs_account"):
            var_lines.append("    is_logs_account = true")
        iam_user_access_to_billing = account["iam_user_access_to_billing"]
        var_lines.append(
            f"    iam_user_access_to_billing = {iam_user_access_to_billing}"
        )
        var_lines.append("    tags = {")
        for tag in account["Tags"]:
            tag_key = tag["Key"]
            tag_val = tag["Value"]
            var_lines.append(f'      "{tag_key}" = "{tag_val}"')
        var_lines.append("    }")
        var_lines.append("  }")

    var_lines.append("  }")
    var_lines.append("}")
    return "\n".join(var_lines)


def generate_landing_zone_imports(import_prefix, accounts, lz_args):
    args = lz_args | {
        "import_prefix": import_prefix,
        "log_archive_id": [
            account["Id"] for account in accounts if account.get("is_logs_account")
        ][0],
        "audit_id": [
            account["Id"] for account in accounts if account.get("is_audit_account")
        ][0],
    }

    template = Template(
        """
import {
  to = ${import_prefix}.module.landing_zone.aws_organizations_account.log_archive
  id = "${log_archive_id}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_organizations_account.audit
  id = "${audit_id}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role.controltower_admin
  id = "AWSControlTowerAdmin"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_policy.controltower_admin_policy
  id = "${admin_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role_policy_attachment.controltower_admin_policy_attachment
  id = "AWSControlTowerAdmin/${admin_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role.cloudtrail
  id = "AWSControlTowerCloudTrailRole"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_policy.cloudtrail_policy
  id = "${cloudtrail_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role_policy_attachment.cloudtrail_policy_attachment
  id = "AWSControlTowerCloudTrailRole/${cloudtrail_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role.stackset
  id = "AWSControlTowerStackSetRole"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_policy.stackset_policy
  id = "${stackset_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role_policy_attachment.stackset_policy_attachment
  id =  "AWSControlTowerStackSetRole/${stackset_policy_arn}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role.config_aggregator
  id = "AWSControlTowerConfigAggregatorRoleForOrganizations"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_iam_role_policy_attachment.config_aggregator
  id =  "AWSControlTowerConfigAggregatorRoleForOrganizations/arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_kms_key.controltower[0]
  id = "${kms_key_id}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_kms_alias.controltower[0]
  id = "alias/control_tower_key"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_kms_key_policy.controltower[0]
  id = "${kms_key_id}"
}

import {
  to = ${import_prefix}.module.landing_zone.aws_controltower_landing_zone.zone
  id = "${landing_zone_arn}"
}
    """
    )
    return template.substitute(args)


def save_cache(d):
    with open("cache.pickle", "wb") as f:
        pickle.dump(d, f, pickle.HIGHEST_PROTOCOL)


def load_cache():
    with open("cache.pickle", "rb") as f:
        return pickle.load(f)


def has_cache():
    p = Path("cache.pickle")
    return p.is_file() and p.stat().st_size > 0


def main():
    parser = argparse.ArgumentParser(
        description="Generate Terraform imports and variables for AWS accounts"
    )
    parser.add_argument("--profile", required=False, help="AWS profile name")
    parser.add_argument(
        "--management-account-id",
        required=True,
        type=str,
        help="Your management account ID",
    )
    parser.add_argument(
        "--import-prefix",
        required=False,
        default="",
        help="The module name prefix to add to all terraform imports.",
    )
    parser.add_argument(
        "--skip-account",
        required=False,
        help="AWS account name to skip",
        action="append",
        default=[],
    )
    args = parser.parse_args()

    profile = args.profile
    if not profile:
        profile = os.environ["AWS_PROFILE"]
        if not profile:
            print("Either pass --profile or set AWS_PROFILE")
            sys.exit(1)

    if has_cache():
        accounts = load_cache()
    else:
        accounts = list_accounts(profile)
        save_cache(accounts)

    accounts = [a for a in accounts if a["Name"] not in args.skip_account]
    accounts = parse_accounts(accounts)
    non_core_accounts = [
        a
        for a in accounts
        if not (
            a.get("is_audit_account")
            or a.get("is_logs_account")
            or a.get("Id") == args.management_account_id
        )
    ]
    account_to_pp = {}
    for account in non_core_accounts:
        account_to_pp[account["Id"]] = get_provisioned_product_by_account_id(
            account["Id"]
        )

    lz_args = {
        "admin_policy_arn": get_admin_policy_arn(),
        "cloudtrail_policy_arn": get_cloudtrail_policy_arn(),
        "stackset_policy_arn": get_stackset_policy_arn(),
        "kms_key_id": get_kms_key_id(),
        "landing_zone_arn": get_landing_zone_arn(),
    }

    # Generate imports.tf
    with open("imports.tf", "w") as f:
        f.write(
            generate_org_imports(args.import_prefix, get_organization_id(profile))
            + generate_ct_account_imports(
                args.import_prefix, non_core_accounts, account_to_pp
            )
        )

        print("Generated imports.tf")

    # Generate child_accounts.tf
    # with open("child_accounts.tf", "w") as f:
    #     f.write(generate_child_accounts_var(accounts))
    #     print("Generated child_accounts.tf")

    # Generate lz_imports.tf
    with open("lz_imports.tf", "w") as f:
        f.write(generate_landing_zone_imports(args.import_prefix, accounts, lz_args))
        print("Generated lz_imports.tf")

    run_terraform_fmt()


if __name__ == "__main__":
    main()
