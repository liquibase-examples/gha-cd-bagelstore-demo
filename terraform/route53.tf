# Route53 DNS Configuration
# Creates DNS records for all 4 environments pointing to App Runner services

# Create CNAME records for each environment
resource "aws_route53_record" "app_runner" {
  for_each = toset(local.environments)

  zone_id = var.route53_zone_id
  name    = "${each.key}-${var.demo_id}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_service.bagel_store[each.key].service_url]
}
