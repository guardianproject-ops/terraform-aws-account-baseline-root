import boto3
import pickle
import argparse
import sys
import os
import subprocess

from pathlib import Path


def run_terraform_fmt():
    try:
        # Run terraform fmt -recursive
        result = subprocess.run(
            ["terraform", "fmt", "-recursive"],
            check=True,
            capture_output=True,
            text=True,
        )

        # If there's any output, print it
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


def list_accountsv1(profile_name):
    session = boto3.session.Session(profile_name=profile_name)
    client = session.client("sts")
    org = session.client("organizations")

    paginator = org.get_paginator("list_accounts")
    page_iterator = paginator.paginate()

    accounts = []

    for page in page_iterator:
        for account in page["Accounts"]:
            accounts.append(account)

    return sorted(accounts, key=lambda k: k["Name"])


def list_accountsv2(profile_name):
    session = boto3.session.Session(profile_name=profile_name)
    client = session.client("sts")
    org = session.client("organizations")

    paginator = org.get_paginator("list_accounts")
    page_iterator = paginator.paginate()

    accounts = []

    for page in page_iterator:
        for account in page["Accounts"]:
            # Get tags for each account
            response = org.list_tags_for_resource(ResourceId=account["Id"])
            account["Tags"] = response.get("Tags", [])
            accounts.append(account)

    return sorted(accounts, key=lambda k: k["Name"])


def list_accounts(profile_name):
    session = boto3.session.Session(profile_name=profile_name)
    client = session.client("sts")
    org = session.client("organizations")

    paginator = org.get_paginator("list_accounts")
    page_iterator = paginator.paginate()

    accounts = []

    for page in page_iterator:
        for account in page["Accounts"]:
            # Get tags for each account
            response = org.list_tags_for_resource(ResourceId=account["Id"])
            account["Tags"] = response.get("Tags", [])

            # Get account details including IAM user access to billing
            try:
                account_details = org.describe_account(AccountId=account["Id"])
                account["IamUserAccessToBilling"] = account_details.get(
                    "Account", {}
                ).get(
                    "IamUserAccessToBilling", "ALLOW"
                )  # Default to ALLOW if not specified
            except org.exceptions.AccountNotFoundException:
                print(f"Warning: Could not find account details for {account['Id']}")
                account["IamUserAccessToBilling"] = (
                    "ALLOW"  # Default to ALLOW if we can't get the info
                )

            accounts.append(account)

    return sorted(accounts, key=lambda k: k["Name"])


def generate_import_blocks(accounts, org_id):
    imports = [
        f"""import {{
  to = module.root_baseline.module.organization.aws_organizations_organization.root[0]
  id = "{org_id}"
        }}"""
    ]
    for account in accounts:
        # Convert account name to a valid terraform identifier
        account_key = account["Name"]
        import_block = f"""import {{
  to = module.root_baseline.module.organization.aws_organizations_account.child_accounts["{account_key}"]
  id = "{account["Id"]}"
}}"""
        imports.append(import_block)
    return imports


def generate_child_accounts_var(accounts):
    var_lines = ["locals {", "child_accounts = {"]

    for account in accounts:
        account_key = account["Name"]  # .lower().replace(" ", "_").replace("-", "_")
        var_lines.append(f'  "{account_key}" = {{')
        var_lines.append(f'    email = "{account["Email"]}"')
        if account["IamUserAccessToBilling"] == "DENOY":
            iam_user_access_to_billing = "false"
        else:
            iam_user_access_to_billing = "true"
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
    return var_lines


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
    args = parser.parse_args()

    profile = args.profile
    if not profile:
        profile = os.environ["AWS_PROFILE"]
        if not profile:
            print("Either pass --profile or set AWS_PROFILE")
            sys.exit(1)

    try:
        if has_cache():
            accounts = load_cache()
        else:
            accounts = list_accounts(profile)
            save_cache(accounts)

        skip_list = ["gp-dev", "keanu-test", "keanu-development", "gp-sandbox"]

        accounts = [a for a in accounts if a["Name"] not in skip_list]

        # Generate imports.tf
        with open("imports.tf", "w") as f:
            imports = generate_import_blocks(accounts, get_organization_id(profile))
            f.write("\n\n".join(imports))
            print("Generated imports.tf")

        # Generate child_accounts.tf
        with open("child_accounts.tf", "w") as f:
            var_lines = generate_child_accounts_var(accounts)
            f.write("\n".join(var_lines))
            print("Generated child_accounts.tf")

        run_terraform_fmt()
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
