#!/usr/bin/perl

# make_primary
#
# This script makes an SCEDC database primary and the other database shadow.

use strict;
use Term::ReadKey;
use DBI;
use DBD::Oracle;

# Database user name and password.
my $user = "";
my $pass = "";

my $enter = 10;  # ASCII value of the ENTER key.
                 # Change to carriage return on Windows.

# Map databases to their corresponding SCEDC server.
my %db_mapping = ("archdbw" => "manaslu", "scsndb" => "lhotse");
my $suffix = ".gps.caltech.edu";

my $read_only = 1;

##### Subroutines ######

sub usage {
    print "usage: make_primary <dbname>\n";
}

# Prompt the user for a database user name.
sub get_db_user {
    print "Database user name: ";
    my $user = <STDIN>;
    chomp($user);
    return $user;
}

# Prompt the user for a database password.
# Code is from http://stackoverflow.com/questions/701078/how-can-i-enter-a-password-using-perl-and-replace-the-characters-with.
sub get_db_password {
    my $pass = "";
    my $key = "";
    ReadMode(4); # Disable control keys.

    # Keep reading characters while the input is the ENTER key.
    while (ord($key = ReadKey(0)) != $enter) {
	if (ord($key) == 127 || ord($key) == 8) {
	    chop($pass);
    
	    print "\b \b";
	}
	elsif(ord($key) > 32) {
	    $pass = $pass . $key;
	    print "*";
	}
    }



    ReadMode(0);  # Return to normal mode.
    print "\n";
    return $pass;
}

# Check if a host is listed as primary in a database.
# arguments: $host -- hostname
#            $dbh -- database handle
sub check_aqms_primary {
    my $host = shift;
    my $dbh = shift;

    my $check_primary = "select primary_system from aqms_host_role where host=:hostname and modification_time in (select max(modification_time) from aqms_host_role where host=:hostname)";
    my $sth = $dbh->prepare($check_primary);
    $sth->bind_param(":hostname", $host);
    $sth->execute();
    if ($sth->err) {
	print $sth->errstr . "\n";
	return -1;
    }
    my @res = $sth->fetchrow_array();
    my $is_primary = lc($res[0]);
    if ($is_primary eq "true") {
	return 1;
    }
    elsif ($is_primary eq "false") {
	return 0;
    }
    else {
	print "'$check_primary' returned unknown result $res[1]\n";
	return -1;
    }
}

#### Main code ####

if ($#ARGV + 1 < 1) {
    &usage;
    exit;
}

my $new_primary = shift(@ARGV);
my $new_shadow = "";
if (!$db_mapping{$new_primary}) {
    print "$new_primary is not a valid SCEDC database.\n";
    exit;
}

if ($new_primary eq "scsndb") {
    $new_shadow = "archdbw";
}
else {
    $new_shadow = "scsndb";
}

if ($#ARGV > 1) {
    if (shift(@ARGV) eq "--test") {
	print "Read-only mode\n";
    }
    else {
	&usage;
	exit;
    }
}

if ($read_only == 1) {
    $user = "browser";
    $pass = "browser";
}
else {
    $user = &get_db_user;
    $pass = &get_db_password;
}

# Set up database and host names.
my $db_new_primary = $new_primary . $suffix;
my $host_new_primary = $db_mapping{$new_primary};
print "new primary host: $host_new_primary\n";

# Connect to databases.
# Connect to new primary database.

my $dbh1 = DBI->connect("dbi:Oracle:$db_new_primary", $user, $pass);

#my $check_primary = "select primary_system from aqms_host_role where host=:hostname and modification_time in (select max(modification_time) from aqms_host_role where host=:hostname)";
my $is_primary = &check_aqms_primary($host_new_primary, $dbh1);
if ($is_primary == 1) {
    print "$new_primary is already the primary AQMS database.\n";
    exit;
}
else {
    print "$new_primary is not the primary AQMS database.\n";
}
# Check who's primary.


# Connect to new shadow databases.
# Check if shadow are shadow.
# If primary is primary, and new shadows are all shadow, then exit.

# Otherwise:
# 1. Make current primary shadow.
# 2. Make new primary primary.

$dbh1->disconnect();

