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
FILEORIG=kangaroo.jpg
# Specify the VIDA-signed output file
FILEVIDA=kangaroo-vida.jpg
#######################################################


all:
	@echo "make keys    # generate public and private keys"
	@echo "make sign    # sign using the sign.sh script"
	@echo "make check   # check signature with the check.sh script"

checkconfig:
	@if [ "$(DOMAIN)" = "example.com" ] ; then \
		echo "ERROR: Makefile is not configured. This won't work."; \
		exit 1; \
	fi

vida-private.pem: checkconfig
	openssl genrsa -out vida-private.pem 2048

vida-public.der: vida-private.pem
	openssl rsa -in vida-private.pem -pubout -outform der 2>/dev/null -out vida-public.der

keys: checkconfig vida-private.pem vida-public.der
	@echo "Add to DNS TXT:"
	@echo "  vida=1 ka=rsa kv=1 p=$$(base64 < vida-public.der | tr -d '\n')"

sign: checkconfig vida-private.pem
	./vida-sign.sh "$(DOMAIN)" "$(FILEORG)" "$(FILEVIDA)"

check: checkconfig
	./vida-verify.sh "$(FILEVIDA)"

