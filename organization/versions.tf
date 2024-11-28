terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.78.0"
      # configuration_aliases = [
      #   aws.af_south_1,
      #   aws.ap_east_1,
      #   aws.ap_northeast_1,
      #   aws.ap_northeast_2,
      #   aws.ap_northeast_3,
      #   aws.ap_south_1,
      #   aws.ap_southeast_1,
      #   aws.ap_southeast_2,
      #   aws.ap_southeast_3,
      #   aws.ca_central_1,
      #   aws.cn_north_1,
      #   aws.cn_northwest_1,
      #   aws.eu_central_1,
      #   aws.eu_north_1,
      #   aws.eu_south_1,
      #   aws.eu_west_1,
      #   aws.eu_west_2,
      #   aws.eu_west_3,
      #   aws.me_south_1,
      #   aws.sa_east_1,
      #   aws.us_east_1,
      #   aws.us_east_2,
      #   aws.us_gov_east_1,
      #   aws.us_gov_west_1,
      #   aws.us_west_1,
      #   aws.us_west_2,
      #   # This is the default region to use for resources that deploy to just one region. Note that the underlying
      #   # module expects a named provider even though it's the default one. This ensures that we explicitly set to
      #   # exactly what we need, rather than having an implicit one get used accidentally. All the providers below this
      #   # one are regional.
      #   aws.default,
      # ]
    }
  }
}
