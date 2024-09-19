#######################################################
# ABOUT:
# Quick and dirty example for signing and verifying.
# Configure your domain and the file to process below.
#######################################################

#######################################################
# CONFIGURE:
# Specify your domain name
DOMAIN=example.com
# Specify the source/original file
FILEORIG=kangaroo-unsigned.jpg
# Specify the SEAL-signed output file
FILESIGNED=kangaroo-signed.jpg
#######################################################


all:
	@echo "make keys    # generate public and private keys"
	@echo "make testdns # check if your DNS contains the seal record"
	@echo "make sign    # sign using the sign.sh script"
	@echo "make check   # check signature with the check.sh script"

checkconfig:
	@if [ "$(DOMAIN)" = "example.com" ] ; then \
		echo "ERROR: Makefile is not configured. This won't work."; \
		exit 1; \
	fi

testdns: checkconfig
	dig TXT "$(DOMAIN)" | grep TXT | grep 'seal=1'

seal-private.pem:
	openssl genrsa -out seal-private.pem 2048

seal-public.der:
	openssl rsa -in seal-private.pem -pubout -outform der 2>/dev/null -out seal-public.der

keys: checkconfig seal-private.pem seal-public.der
	@echo "Add to DNS TXT:"
	@echo "  seal=1 ka=rsa kv=1 p=$$(base64 < seal-public.der | tr -d '\n')"

sign: checkconfig seal-private.pem
	./seal-sign.sh "$(DOMAIN)" seal-private.pem "$(FILEORIG)" "$(FILESIGNED)"

check: checkconfig
	./seal-verify.sh "$(FILESIGNED)"

