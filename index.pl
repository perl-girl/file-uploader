#!/usr/bin/perl
# Measurement Management System -- index/dispatcher module
# $Id: index.pl 156 2011-09-28 20:30:16Z msiegman $

use lib './source';
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 
use Index;
my $app = Index->new();
$app->run();
