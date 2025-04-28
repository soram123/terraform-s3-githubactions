provider "aws" {
  region = "ap-south-1" # Mumbai region
  
}



# Reference existing S3 bucket (won't try to recreate it)
data "aws_s3_bucket" "app" {
  bucket = "soram-terraform-cloudfront"
  
}

# CloudFront Origin Access Identity for secure access
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for React app"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = data.aws_s3_bucket.app.bucket_regional_domain_name
    origin_id   = "s3-origin"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "React app distribution"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-origin"
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = []
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # SPA routing - return index.html for 404s
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Allow CloudFront to access S3 bucket
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = data.aws_s3_bucket.app.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        },
        Action    = "s3:GetObject",
        Resource  = "${data.aws_s3_bucket.app.arn}/*"
      }
    ]
  })
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "s3_origin" {
  value = "s3://${data.aws_s3_bucket.app.bucket}"
}