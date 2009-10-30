S3 = RightAws::S3.new(Settings.amazon.access_key, Settings.amazon.secret_key)
BUCKET = S3.bucket(Settings.amazon.bucket, true, 'public-read')
