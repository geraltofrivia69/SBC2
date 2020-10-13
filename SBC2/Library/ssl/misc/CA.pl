#!C:/Users/Chuck/Anaconda3/envs/SBC2\Library\bin\perl.exe
# Copyright 2000-2018 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the OpenSSL license (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

#
# Wrapper around the ca to make it easier to use
#
# WARNING: do not edit!
# Generated by makefile from apps\CA.pl.in

use strict;
use warnings;

my $openssl = "openssl";
if(defined $ENV{'OPENSSL'}) {
    $openssl = $ENV{'OPENSSL'};
} else {
    $ENV{'OPENSSL'} = $openssl;
}

my $verbose = 1;

my $OPENSSL_CONFIG = $ENV{"OPENSSL_CONFIG"} || "";
my $DAYS = "-days 365";
my $CADAYS = "-days 1095";	# 3 years
my $REQ = "$openssl req $OPENSSL_CONFIG";
my $CA = "$openssl ca $OPENSSL_CONFIG";
my $VERIFY = "$openssl verify";
my $X509 = "$openssl x509";
my $PKCS12 = "$openssl pkcs12";

# default openssl.cnf file has setup as per the following
my $CATOP = "./demoCA";
my $CAKEY = "cakey.pem";
my $CAREQ = "careq.pem";
my $CACERT = "cacert.pem";
my $CACRL = "crl.pem";
my $DIRMODE = 0777;

my $NEWKEY = "newkey.pem";
my $NEWREQ = "newreq.pem";
my $NEWCERT = "newcert.pem";
my $NEWP12 = "newcert.p12";
my $RET = 0;
my $WHAT = shift @ARGV || "";
my @OPENSSL_CMDS = ("req", "ca", "pkcs12", "x509", "verify");
my %EXTRA = extra_args(\@ARGV, "-extra-");
my $FILE;

sub extra_args {
    my ($args_ref, $arg_prefix) = @_;
    my %eargs = map {
	if ($_ < $#$args_ref) {
	    my ($arg, $value) = splice(@$args_ref, $_, 2);
	    $arg =~ s/$arg_prefix//;
	    ($arg, $value);
	} else {
	    ();
	}
    } reverse grep($$args_ref[$_] =~ /$arg_prefix/, 0..$#$args_ref);
    my %empty = map { ($_, "") } @OPENSSL_CMDS;
    return (%empty, %eargs);
}

# See if reason for a CRL entry is valid; exit if not.
sub crl_reason_ok
{
    my $r = shift;

    if ($r eq 'unspecified' || $r eq 'keyCompromise'
        || $r eq 'CACompromise' || $r eq 'affiliationChanged'
        || $r eq 'superseded' || $r eq 'cessationOfOperation'
        || $r eq 'certificateHold' || $r eq 'removeFromCRL') {
        return 1;
    }
    print STDERR "Invalid CRL reason; must be one of:\n";
    print STDERR "    unspecified, keyCompromise, CACompromise,\n";
    print STDERR "    affiliationChanged, superseded, cessationOfOperation\n";
    print STDERR "    certificateHold, removeFromCRL";
    exit 1;
}

# Copy a PEM-format file; return like exit status (zero means ok)
sub copy_pemfile
{
    my ($infile, $outfile, $bound) = @_;
    my $found = 0;

    open IN, $infile || die "Cannot open $infile, $!";
    open OUT, ">$outfile" || die "Cannot write to $outfile, $!";
    while (<IN>) {
        $found = 1 if /^-----BEGIN.*$bound/;
        print OUT $_ if $found;
        $found = 2, last if /^-----END.*$bound/;
    }
    close IN;
    close OUT;
    return $found == 2 ? 0 : 1;
}

# Wrapper around system; useful for debugging.  Returns just the exit status
sub run
{
    my $cmd = shift;
    print "====\n$cmd\n" if $verbose;
    my $status = system($cmd);
    print "==> $status\n====\n" if $verbose;
    return $status >> 8;
}


if ( $WHAT =~ /^(-\?|-h|-help)$/ ) {
    print STDERR "usage: CA.pl -newcert | -newreq | -newreq-nodes | -xsign | -sign | -signCA | -signcert | -crl | -newca [-extra-cmd extra-params]\n";
    print STDERR "       CA.pl -pkcs12 [-extra-pkcs12 extra-params] [certname]\n";
    print STDERR "       CA.pl -verify [-extra-verify extra-params] certfile ...\n";
    print STDERR "       CA.pl -revoke [-extra-ca extra-params] certfile [reason]\n";
    exit 0;
}
if ($WHAT eq '-newcert' ) {
    # create a certificate
    $RET = run("$REQ -new -x509 -keyout $NEWKEY -out $NEWCERT $DAYS $EXTRA{req}");
    print "Cert is in $NEWCERT, private key is in $NEWKEY\n" if $RET == 0;
} elsif ($WHAT eq '-precert' ) {
    # create a pre-certificate
    $RET = run("$REQ -x509 -precert -keyout $NEWKEY -out $NEWCERT $DAYS");
    print "Pre-cert is in $NEWCERT, private key is in $NEWKEY\n" if $RET == 0;
} elsif ($WHAT =~ /^\-newreq(\-nodes)?$/ ) {
    # create a certificate request
    $RET = run("$REQ -new $1 -keyout $NEWKEY -out $NEWREQ $DAYS $EXTRA{req}");
    print "Request is in $NEWREQ, private key is in $NEWKEY\n" if $RET == 0;
} elsif ($WHAT eq '-newca' ) {
    # create the directory hierarchy
    mkdir ${CATOP}, $DIRMODE;
    mkdir "${CATOP}/certs", $DIRMODE;
    mkdir "${CATOP}/crl", $DIRMODE ;
    mkdir "${CATOP}/newcerts", $DIRMODE;
    mkdir "${CATOP}/private", $DIRMODE;
    open OUT, ">${CATOP}/index.txt";
    close OUT;
    open OUT, ">${CATOP}/crlnumber";
    print OUT "01\n";
    close OUT;
    # ask user for existing CA certificate
    print "CA certificate filename (or enter to create)\n";
    $FILE = "" unless defined($FILE = <STDIN>);
    $FILE =~ s{\R$}{};
    if ($FILE ne "") {
        copy_pemfile($FILE,"${CATOP}/private/$CAKEY", "PRIVATE");
        copy_pemfile($FILE,"${CATOP}/$CACERT", "CERTIFICATE");
    } else {
        print "Making CA certificate ...\n";
        $RET = run("$REQ -new -keyout"
                . " ${CATOP}/private/$CAKEY"
                . " -out ${CATOP}/$CAREQ $EXTRA{req}");
        $RET = run("$CA -create_serial"
                . " -out ${CATOP}/$CACERT $CADAYS -batch"
                . " -keyfile ${CATOP}/private/$CAKEY -selfsign"
                . " -extensions v3_ca $EXTRA{ca}"
                . " -infiles ${CATOP}/$CAREQ") if $RET == 0;
        print "CA certificate is in ${CATOP}/$CACERT\n" if $RET == 0;
    }
} elsif ($WHAT eq '-pkcs12' ) {
    my $cname = $ARGV[0];
    $cname = "My Certificate" unless defined $cname;
    $RET = run("$PKCS12 -in $NEWCERT -inkey $NEWKEY"
            . " -certfile ${CATOP}/$CACERT"
            . " -out $NEWP12"
            . " -export -name \"$cname\" $EXTRA{pkcs12}");
    print "PKCS #12 file is in $NEWP12\n" if $RET == 0;
} elsif ($WHAT eq '-xsign' ) {
    $RET = run("$CA -policy policy_anything $EXTRA{ca} -infiles $NEWREQ");
} elsif ($WHAT eq '-sign' ) {
    $RET = run("$CA -policy policy_anything -out $NEWCERT $EXTRA{ca} -infiles $NEWREQ");
    print "Signed certificate is in $NEWCERT\n" if $RET == 0;
} elsif ($WHAT eq '-signCA' ) {
    $RET = run("$CA -policy policy_anything -out $NEWCERT"
            . " -extensions v3_ca $EXTRA{ca} -infiles $NEWREQ");
    print "Signed CA certificate is in $NEWCERT\n" if $RET == 0;
} elsif ($WHAT eq '-signcert' ) {
    $RET = run("$X509 -x509toreq -in $NEWREQ -signkey $NEWREQ"
            . " -out tmp.pem $EXTRA{x509}");
    $RET = run("$CA -policy policy_anything -out $NEWCERT"
            . "$EXTRA{ca} -infiles tmp.pem") if $RET == 0;
    print "Signed certificate is in $NEWCERT\n" if $RET == 0;
} elsif ($WHAT eq '-verify' ) {
    my @files = @ARGV ? @ARGV : ( $NEWCERT );
    my $file;
    foreach $file (@files) {
        my $status = run("$VERIFY \"-CAfile\" ${CATOP}/$CACERT $file $EXTRA{verify}");
        $RET = $status if $status != 0;
    }
} elsif ($WHAT eq '-crl' ) {
    $RET = run("$CA -gencrl -out ${CATOP}/crl/$CACRL $EXTRA{ca}");
    print "Generated CRL is in ${CATOP}/crl/$CACRL\n" if $RET == 0;
} elsif ($WHAT eq '-revoke' ) {
    my $cname = $ARGV[0];
    if (!defined $cname) {
        print "Certificate filename is required; reason optional.\n";
        exit 1;
    }
    my $reason = $ARGV[1];
    $reason = " -crl_reason $reason"
        if defined $reason && crl_reason_ok($reason);
    $RET = run("$CA -revoke \"$cname\"" . $reason . $EXTRA{ca});
} else {
    print STDERR "Unknown arg \"$WHAT\"\n";
    print STDERR "Use -help for help.\n";
    exit 1;
}

exit $RET;
