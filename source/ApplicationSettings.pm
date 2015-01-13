# File Uploader
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
    SERVER  => 'http://eberman.na.xerox.net',

    APP_PATH => '/var/www/html/uploader/',
    APP_URL  => '/uploader/',
    
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
    RESOURCES => "/resources",
    JQUERY    => "https://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js",
    BOOTCSS   => "//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap.min.css",
    BOOTJS    => "//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/js/bootstrap.min.js",

    # application information
    FULLNAME => "File Uploader",
    VERSION => "1.0",

    # location stuff
    LOCATION    => {
        DEFAULT_COUNTRY => 'US',
    },

    # file repository
    FILE_REPO   => '/var/www/html/uploads/',
    TEMP_REPO   => '/tmp/',
    FILE_MAGIK  => '/usr/bin/file -ib',
    UMASK       => 0113,

);

# accessor function
sub GetSettings {
    return $SETTINGS{$_[0]};
}
