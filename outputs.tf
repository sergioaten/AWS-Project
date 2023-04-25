###########
# Output URL Acces web
###########

output "url_web" {
  value = format("%s/cafe", aws_lb.app.dns_name)
}