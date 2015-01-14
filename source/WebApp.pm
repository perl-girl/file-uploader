# File Uploader
# ########################################################################### #
# Web Application Framework / Base Class
# Implementation code
# $Id: WebApp.pm 1050 2014-07-08 00:32:26Z eberman $
# ########################################################################### #

package WebApp;
use strict;
use ApplicationSettings qw/GetSettings/;

# CGI & CGI::App stuff
use base 'CGI::Application';       
use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::TT;
use CGI::Application::Plugin::Session;
use CGI;
use Data::Dumper;

$CGI::POST_MAX = 1024 * 100000;#max upload of 100MB... for now!

# setup & enable logging
use Log::Log4perl;
Log::Log4perl->init(GetSettings("APP_PATH")."/source/log4perl.conf");



sub setup {
    my $self = shift;

    # some CGI::App stuff
    $self->run_modes("AUTOLOAD" => \&bad_rm);
    $self->mode_param(path_info => 1);
    $self->error_mode('error_runmode');

    # build the path tree
    $self->{path} = $self->query->url(-absolute=>1);
    $self->{suitepath} = GetSettings("APP_URL");
    my %SUITE = %{GetSettings("SUITE")};
    for my $key (keys %SUITE) {
        if( $SUITE{$key} =~ /^\^/ ) {
            $SUITE{$key} =~ s/^\^//;
        }
        else {
            $SUITE{$key} = $self->{suitepath} . "/" . $SUITE{$key}
        }
    }

    # setup Template Toolkit
    $self->tt_config(TEMPLATE_OPTIONS => {
        INCLUDE_PATH => GetSettings("APP_PATH") . '/template',
        COMPILE_DIR  => GetSettings("APP_PATH") . '/cache',
    },);

    my $tt_runmode;
    eval {
        $tt_runmode = $self->{__MODE_PARAM}{run_mode};
    };
        
    
    # standard template parameters
    my %tt_params = (
        ENV => \%ENV,
        APPLICATION => {
            AJAX => $self->{ajax},
            PATH => $self->{path},
            RUNMODE => $tt_runmode,
            SUITE => {
                PATH => $self->{suitepath},
                ENTRY => $self->{suitepath} . "/index.pl",
                %SUITE,
            },
            LOCATION => GetSettings("LOCATION"),
            JQUERY => GetSettings("JQUERY"),
            RESOURCES => GetSettings("RESOURCES"),
            BOOTCSS  => GetSettings("BOOTCSS"),
            BOOTJS  => GetSettings("BOOTJS"),
            UPLOAD => GetSettings("UPLOAD"),
            FULLNAME => GetSettings("FULLNAME"),
            VERSION => GetSettings("VERSION"),
            DEBUG_MODE => GetSettings("DEBUG_MODE"),
        },
    );

    # tell TT about its standard parameters
    $self->tt_params(%tt_params);
}

sub get_setting {
    return GetSettings($_[1]);
}

sub Vars {
    my $self = shift;
    my $q = $self->query;

    my @p = $q->param;
    my %params;
    for my $key ( $q->param ) {
        my @val = $q->param( $key );
        ( $params{$key} ) = @val < 2 ? @val : ( \@val );
    }
    return %params;
}

sub app_vars {
    my $self = shift;
    my $q = $self->query;

    my @p = $q->param;
    my %params;
    for my $key ( $q->param ) {
        my @val = $q->param( $key );
        ( $params{$key} ) = @val < 2 ? @val : ( \@val );
    }
    return %params;
}

sub bad_rm {
    my ($self, $intended_runmode) = @_;

    #$intended_runmode = $self->query->escapeHTML($intended_runmode);
    Log::Log4perl->get_logger()->debug("runmodes: " . Dumper { $self->run_modes() }); 
    Log::Log4perl->get_logger()->fatal("bad runmode: $intended_runmode");

    return "That run mode does not exist.";
}

sub cgiapp_postrun {
    my $self = shift;
    $self->session->flush if $self->session_loaded;
}

sub empty_runmode : Runmode {}

sub _die {
    my $self = shift;
    print $self->error_runmode("Invalid database setup");
    exit;
}

sub error_runmode {
    my ($self) = shift;

    Log::Log4perl->get_logger()->fatal(@_);
    Log::Log4perl->get_logger()->logcluck();

    my $details = {
        uri   => $self->tt_params->{'ENV'}{'REQUEST_URI'}, 
        user  => $self->tt_params->{"CURRENT_USER"}{"info"}{"fname"} . " " .
                 $self->tt_params->{"CURRENT_USER"}{"info"}{"lname"},
        phone => $self->tt_params->{"CURRENT_USER"}{"info"}{"phone"},
        email => $self->tt_params->{"CURRENT_USER"}{"info"}{"email"},
    };

    return $self->tt_process("resources/error_form", $details ) or "An error has occured";

}
