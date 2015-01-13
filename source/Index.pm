# File Uploader
# ###################################################################### #
# Index / Dispatch Module
# Implementation code
# $Id: Index.pm 1050 2014-07-18 16:29:01Z eberman $
# ###################################################################### #
package Index;

use lib '.';
use base 'WebApp';
use aliased 'File::Find::Rule';
use File::Basename;
use File::Path qw/remove_tree/;
use DBI;
use JSON;
use strict;

our $logger = Log::Log4perl->get_logger();

sub Help : Runmode {
    my $self = shift;

    return $self->tt_process();
}

sub Suggestion : Runmode {
    my $self = shift;
    
    return $self->tt_process();
}

sub Index : StartRunmode {
    my $self = shift;

    my $data;
    my $active;

    return $self->tt_process($data);
}


# Technically not a true AJAX call as it's called using a hidden iframe 
# to support the wonderful browser known affectionately as Internet 
# Exploder 8 which is unable to upload files using AJAX

sub FileUploadAJAX : Runmode {
    
    my $self = shift;
    my %vars = $self->Vars();

    my $files = $vars{filenames};

# cheesy way of dealing with a single file
    if (ref $files eq 'Fh') { 
        $files = [$files];
    }

    my $outdir = ApplicationSettings::GetSettings('FILE_REPO');

# save temp directory to session
    $self->session->param("outdir", $outdir);

# write uploaded files to temp directory
    foreach my $file (@$files) {
        my $fname = $file;
# because IE8 uses the absolute path as the filename, 
# and it's fewer lines than using File::Basename
        $fname =~ s/[a-zA-Z]:.*\\//;

        open my $fh, ">", "$outdir/$fname" or $logger->fatal("Unable to create file $! $@");
        $logger->debug("$outdir/$fname");
        binmode $fh;

        while (<$file>) {
            print $fh $_;
        } 

        close $fh;
    }
# originally got the output directory from the iframe, but now it's
# saved in the CGI session, so this is kinda redundant...
}

sub FileInfoAJAX : Runmode {

    my $self = shift;

    my %vars = $self->Vars();
    my $outdir = $self->session->param("outdir");

    my $data;


    my @files = Rule->file->in($outdir);

    $data->{files} = [];

# Get the file info and return it to the page
    foreach my $file (@files) {
        my @stats = stat $file;
        push(
            @{$data->{files}}, 
            {
                name  => basename($file),
                size  => sprintf( "%.2f %s", ($stats[7]/1024)/1024, "MB"),
                valid => 1
            }
        );
    }
    return encode_json $data;
}

sub FileScanAJAX : Runmode {
    
    my $self = shift;
    my %vars = $self->Vars();

    my $FileDir = $self->session->param("outdir");
    my $File = $vars{FILE};

    my $magic = ApplicationSettings::GetSettings('FILE_MAGIK');
    my $FilePath = "$FileDir/$File";


# check the file type.
    my $ftype = qx/$magic $FilePath/;

        
    my $data;

    my $basename = $FilePath; 

    return encode_json $data if defined $data;
    return 1;
    
}




1;
