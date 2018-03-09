Log in 

Click username at top right

Pick Security Credentials

Go to Identity Access Management

Pick the user to open Summary

Click Security credentials tab

Click "Create access key"

This will give you an Access key ID and a Secret access key.

Getting started with aws command line interface:
https://github.com/aws/aws-cli#getting-started

Init script:
https://stackoverflow.com/a/10128171

Uploading known SSH key:
https://alestic.com/2012/04/ec2-ssh-host-key/

AWS example documentation:
https://github.com/awsdocs/aws-doc-sdk-examples

Create security group (Python):
https://github.com/awsdocs/aws-doc-sdk-examples/blob/3c396bc74bfc8c1d2503d316bd2b3be2d9630ae5/python/example_code/ec2/create_security_group.py



Note: 
in the machine, get metadata like this:

$ curl http://169.254.169.254/latest/meta-data/

$ curl http://169.254.169.254/latest/meta-data/local-ipv4
10.11.0.192

$ curl http://169.254.169.254/latest/meta-data/public-ipv4
13.56.232.96



