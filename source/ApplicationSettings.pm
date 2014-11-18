# Measurement Management System
# ########################################################################### #
# Application Settings Module
# $Id: ApplicationSettings.pm.default 688 2014-08-18 15:20:36Z eberman $
# ########################################################################### #

package ApplicationSettings;
use strict;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA = qw/Exporter/;
    @EXPORT_OK = qw/GetSettings/;
}

my %SETTINGS = (
    #This is needed for async jobs that don't have     
    #access to environment info
    SERVER  => 'http://erics.bftc.learjet.com',

    APP_PATH => '/mnt/ua1/dev_envs/erics/inst/ops/iads_aw_upload',
    APP_URL  => '/inst/ops/iads_aw_upload',
    
    DEBUG_MODE => 1,

    #Entry Point
    ENTRY           => {
        module => 'Index', 
        runmode => 'Index'
    },

    # Application pieces
    SUITE => {
        INDEX           => "index.pl",
    },

    # resource file locations
    RESOURCES => "/inst/ops/iads_aw_upload/resources",
    JQUERY    => "/js/jquery-1.7.2.min.js",

    # application information
    FULLNAME => "IADS Analysis Window Uploader",
    VERSION => "1.0",

    # location stuff
    LOCATION    => {
        DEFAULT_COUNTRY => 'US',
    },

    # file repository
    FILE_REPO   => '/mnt/ua1/dev_envs/erics/inst/ops/iads_aw_upload/tempfiles/',
    FILE_MAGIK  => '/usr/bin/file -ib',
    UMASK       => 0113,

);

# accessor function
sub GetSettings {
    return $SETTINGS{$_[0]};
}
