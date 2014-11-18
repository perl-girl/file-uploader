# Analysis Window Uploader
# ###################################################################### #
# Index / Dispatch Module
# Implementation code
# $Id: Index.pm 1050 2014-07-18 16:29:01Z eberman $
# ###################################################################### #
package Index;

use base 'WebApp';
use Local::BFTC::Aircraft;
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
    my $airplanes = Local::BFTC::Aircraft->new;
    my $active;

    @$active = grep { 
        $airplanes->{$_}{active} == 1 
        and $_ !~ m/(fti|afdx|ttp|sits)/
    } keys %$airplanes; 

    @$active = sort { $a <=> $b } @$active;

    $data->{aircraft} = $active;

    return $self->tt_process($data);
}


# Technically not a true AJAX call as it's called using a hidden iframe 
# to support the wonderful browser known affectionately as Internet 
# Exploder 8 which is unable to upload files using AJAX

sub FileUploadAJAX : Runmode {
    
    my $self = shift;
    my %vars = $self->Vars();

# save aircraft info to session
    $self->session->param("aircraft", $vars{aircraft});


    my $files = $vars{filenames};

# cheesy way of dealing with a single file
    if (ref $files eq 'Fh') { 
        $files = [$files];
    }

    my $outdir = ApplicationSettings::GetSettings('FILE_REPO') . 
        (int(rand(131072)) + 131072);
    mkdir $outdir;

# save temp directory to session
    $self->session->param("outdir", $outdir);

# write uploaded files to temp directory
    foreach my $file (@$files) {
        my $fname = $file;
# because IE8 uses the absolute path as the filename, 
# and it's fewer lines than using File::Basename
        $fname =~ s/[a-zA-Z]:.*\\//;

        open my $fh, ">", "$outdir/$fname";
        binmode $fh;

        while (<$file>) {
            print $fh $_;
        } 

        close $fh;
    }
# originally got the output directory from the iframe, but now it's
# saved in the CGI session, so this is kinda redundant...
    return "<span id='outdir'>$outdir</span>";
}

sub FileInfoAJAX : Runmode {

    my $self = shift;

    my %vars = $self->Vars();
    my $outdir = $self->session->param("outdir");

    my $data;


    my @aws = Rule->file->in($outdir);

    $data->{aws} = [];

# Get the file info and return it to the page
    foreach my $aw (@aws) {
        my @stats = stat $aw;
        push(
            @{$data->{aws}}, 
            {
                name  => basename($aw),
                size  => sprintf( "%.2f %s", $stats[7]/1024, "KB"),
                valid => basename($aw) =~ m/\.iadsAw(\.zip)?/ ? 1 : 0
            }
        );
    }
    return encode_json $data;
}

sub FileScanAJAX : Runmode {
    
    my $self = shift;
    my %vars = $self->Vars();

    my $AwDir = $self->session->param("outdir");
    my $Aw = $vars{AW};

    $self->_GetParmDef();
    $self->_GetTmParams();

    my $magic = ApplicationSettings::GetSettings('FILE_MAGIK');
    my $AwFilePath = "$AwDir/$Aw";


# check the file type.
    my $ftype = qx/$magic $AwFilePath/;

        
    my $data;
    @{$data->{errors}} = ();
    @{$data->{warnings}} = ();

    my $basename = $AwFilePath; 
# extract zipped files
    if ($ftype =~ m/zip/i) {
        $basename =  basename($AwFilePath, '.zip');
        use Archive::Zip;
        my $zipper = Archive::Zip->new();
        $zipper->read($AwFilePath);
        my @members = $zipper->memberNames();
        my $aws = grep {m/.*\.iadsAw/} @members;
        if ($aws > 1 or $aws < 1) {
            push @{$data->{errors}}, "Only one .iadsAw file allowed per .zip!";
            return encode_json $data;
        }
        foreach my $member (@members) {
            my $memname = $member =~ m/.*\.iadsAw/ ? $basename : $member;
            $zipper->extractMemberWithoutPaths($member, "$AwDir/$memname");
        }

    }


    open my $AwFile, "<", $basename
        or $logger->fatal("could not open $Aw!");

    
    foreach my $line (<$AwFile>) {
        
        if ($line =~ m/updat3 ParameterDefaults/) {
# freaking pipe-separated CSV files...
            my @parts = split(/\|/, $line);
            my $dsa = $parts[11];

# scan for caldb-type parameters
            while ($dsa =~ m/([A-Z][0-9]{2}[A-Z0-9]{5,6})/g) {
                $self->{AwParms}{$1}{TM} = 0;
                $self->{AwParms}{$1}{Parmdef} = 0;
            }
        }
    }


    foreach my $param (keys %{$self->{AwParms}}) {

# parameter is in the telemetry stream if it's in the TM_parms hash
# or is a derived parameter or constant
        $self->{AwParms}{$param}{TM} = 1 
            if ($self->{TM_parms}{$param}{parm_name} eq $param
            or $self->{parmdef}{$param}{type} =~ m/(DERIVED|CONSTANT)/);
# check if parameter actually exists in the database
        $self->{AwParms}{$param}{parmdef} = 1
            if $self->{parmdef}{$param}{parm_name} eq $param;

        push @{$data->{errors}}, $param
            if $self->{AwParms}{$param}{parmdef} == 0;
        push @{$data->{warnings}}, $param
            if $self->{AwParms}{$param}{TM} == 0;
    }
    if (scalar @{$data->{warnings}} > 1) {
        @{$data->{warnings}} = sort { $a cmp $b } @{$data->{warnings}};
    }
    if (scalar @{$data->{errors}} > 1) {
        @{$data->{errors}} = sort { $a cmp $b } @{$data->{errors}};
    }


    return encode_json $data if defined $data;
    return 1;
    
}

sub _GetCalDB {
    my $self = shift;

    my $airplanes = Local::BFTC::Aircraft->new;

    my $ac = $self->session->param("aircraft");
    my $ac_info = $airplanes->{$ac};
    
    eval {
        $self->{cdb} = DBI->connect(
            "dbi:Oracle:caldb",
            $ac_info->{cdb_name},
            $ac_info->{cdb_pass},
            {   
                FetchHashKeyName => "NAME_lc",
                PrintError       => 0
            }   
        );  
        return 1;
    } or do {
        $self->{cdb} = undef;
        $logger->error("No CalDB for aircraft $ac\n");
        return  "No CalDB for aircraft '$ac'!\n$@\n";
    };
}

sub _GetParmDef {

    my $self = shift;
    $self->_GetCalDB if not defined $self->{cdb};

    my $stm = "SELECT * FROM AC_PARM_DEF";
    my $sth = $self->{cdb}->prepare($stm);
    $sth->execute();

    my $results = $sth->fetchall_hashref("parm_name");
    $self->{parmdef} = $results;


}

sub _GetTmParams { 
    
    my $self = shift;
    $self->_GetCalDB if not defined $self->{cdb};

    my $stm = qq/SELECT MAX(flt_gr_num) as maxfg FROM ac_data_map_def
        WHERE flt_gr_num < 90009000/;
    my $sth = $self->{cdb}->prepare($stm);
    $sth->execute();
    my $fgnum = $sth->fetchrow_array();

    $stm = qq/SELECT * FROM ac_data_map_def 
        WHERE flt_gr_num = $fgnum/;
    my $sth = $self->{cdb}->prepare($stm);
    $sth->execute();
    my $results = $sth->fetchall_hashref("parm_name");
    $self->{TM_parms} = $results;

}


1;
