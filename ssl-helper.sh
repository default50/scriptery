#!/bin/bash

if [ $UID != 0 ]; then
        echo "You must be root to use this script."
        exit 1
fi

if [ ! $# == 2 ]; then
        echo "Use: $0 { view | create | sign | view-cert } <service-name>"
        exit 1
fi

OPENSSL=`which openssl`
SSL_DIR=/etc/ssl
SSL_CONF=$SSL_DIR/openssl.cnf
CA_DIR=$SSL_DIR/MyCA

case "$1" in
        view)
        $OPENSSL req -in $CA_DIR/$2.req.pem -text -verify -noout | less
        ;;
        create)
        $OPENSSL req -new -nodes -out $CA_DIR/$2.req.pem -config $SSL_CONF
        mv key.pem $CA_DIR/$2.key.pem
        ;;
        sign)
        $OPENSSL ca -out $CA_DIR/$2.cert.pem -config $SSL_CONF -infiles $CA_DIR/$2.req.pem
        ;;
        view-cert)
        $OPENSSL x509 -in $CA_DIR/$2.cert.pem -noout -text -purpose | less
        ;;
        *)
        echo "$1 is not a valid action!"
        ;;
esac

chmod 400 $CA_DIR/*.pem

