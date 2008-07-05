# --
# Kernel/System/Support/Database/postgresql.pm - all required system information
# Copyright (C) 2001-2008 OTRS AG, http://otrs.org/
# --
# $Id: postgresql.pm,v 1.7 2008-07-05 14:37:52 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl-2.0.txt.
# --

package Kernel::System::Support::Database::postgresql;

use strict;
use warnings;

use Kernel::System::XML;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.7 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(ConfigObject LogObject DBObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    $Self->{XMLObject} = Kernel::System::XML->new(%Param);

    return $Self;
}

sub SupportConfigArrayGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw()) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }
}

sub SupportInfoGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ModuleInputHash} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
        return;
    }
    if ( ref( $Param{ModuleInputHash} ) ne 'HASH' ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'ModuleInputHash must be a hash reference!',
        );
        return;
    }

    # add new function name here
    my @ModuleList = (
        '_DatestyleCheck', '_UTF8ServerCheck',
        '_TableCheck', '_UTF8ClientCheck',
        '_VersionCheck',
    );

    my @DataArray;

    FUNCTIONNAME:
    for my $FunctionName (@ModuleList) {

        # run function and get check data
        my $Check = $Self->$FunctionName( Type => $Param{ModuleInputHash}->{Type} || '', );

        next FUNCTIONNAME if !$Check;

        # attach check data if valid
        push @DataArray, $Check;
    }

    return \@DataArray;
}

sub AdminChecksGet {
    my ( $Self, %Param ) = @_;

    # add new function name here
    my @ModuleList = (
        '_DatestyleCheck', '_UTF8ServerCheck',
        '_TableCheck', '_UTF8ClientCheck',
        '_VersionCheck',
    );

    my @DataArray;

    FUNCTIONNAME:
    for my $FunctionName (@ModuleList) {

        # run function and get check data
        my $Check = $Self->$FunctionName();

        next FUNCTIONNAME if !$Check;

        # attach check data if valid
        push @DataArray, $Check;
    }

    return \@DataArray;
}

sub _TableCheck {
    my ( $Self, %Param ) = @_;

    my $Data = {};

    # table check
    my $File = $Self->{ConfigObject}->Get('Home') . '/scripts/database/otrs-schema.xml';
    if ( -f $File ) {
        my $Count   = 0;
        my $Check   = 'Failed';
        my $Message = '';
        my $Content = '';
        my $In;
        if ( open( $In, '<', $File ) ) {
            while (<$In>) {
                $Content .= $_;
            }
            close($In);
            my @XMLHash = $Self->{XMLObject}->XMLParse2XMLHash( String => $Content );
            for my $Table ( @{ $XMLHash[1]->{database}->[1]->{Table} } ) {
                if ($Table) {
                    $Count++;
                    if ( $Self->{DBObject}->Prepare( SQL => "select * from $Table->{Name}", Limit => 1 ) )
                    {
                        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
                        }
                    }
                    else {
                        $Message .= "$Table->{Name}, ";
                    }
                }
            }
            if ($Message) {
                $Message = "Table dosn't exists: $Message";
            }
            else {
                $Check   = 'OK';
                $Message = "$Count Tables";
            }
            $Data = {
                Key         => 'TableCheck',
                Name        => 'Table Check',
                Description => 'Check existing framework tables.',
                Comment     => $Message,
                Check       => $Check,
            };
        }
        else {
            $Data = {
                Key         => 'TableCheck',
                Name        => 'Table Check',
                Description => 'Check existing framework tables.',
                Comment     => "Can't open file $File: $!",
                Check       => $Check,
            };
        }
    }
    else {
        $Data = {
            Key         => 'TableCheck',
            Name        => 'Table Check',
            Description => 'Check existing framework tables.',
            Comment     => "Can't find file $File!",
            Check       => 'Failed',
        };
    }
    return $Data;
}

sub _DatestyleCheck {
    my ( $Self, %Param ) = @_;

    my $Data = {};

    # Datestyle check
    my $Check   = 'Failed';
    my $Message = 'No DateStyle found!';
    $Self->{DBObject}->Prepare( SQL => 'show all' );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Row[0] =~ /^DateStyle/i ) {
            if ( $Row[1] =~ /^ISO/i ) {
                $Check   = 'OK';
                $Message = "$Row[1]";
            }
            else {
                $Check   = 'Failed';
                $Message = "Unkown DateStyle ($Row[1]) need ISO.";
            }
        }
    }
    $Data = {
        Key         => 'DateStyle',
        Name        => 'DateStyle',
        Description => 'Check DateStyle.',
        Comment     => $Message,
        Check       => $Check,
        },
        return $Data;
}

sub _UTF8ServerCheck {
    my ( $Self, %Param ) = @_;

    my $Data = {};

    # utf-8 server check
    if ( $Self->{ConfigObject}->Get('DefaultCharset') =~ /utf(\-8|8)/i ) {
        my $Check   = 'Failed';
        my $Message = 'No server_encoding found!';
        $Self->{DBObject}->Prepare( SQL => 'show all' );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            if ( $Row[0] =~ /^server_encoding/i ) {
                $Message = "server_encoding found but it's set to '$Row[1]' (need to be UNICODE or UTF8)";
                if ( $Row[1] =~ /(UNICODE|utf(8|\-8))/i ) {
                    $Check   = 'OK';
                    $Message = "$Row[1]";
                }
            }
        }
        $Data = {
            Key         => 'utf8 server connection',
            Name        => 'Server Connection (utf8)',
            Description => 'Check the utf8 server connection.',
            Comment     => $Message,
            Check       => $Check,
        };
    }
    return $Data;
}

sub _UTF8ClientCheck {
    my ( $Self, %Param ) = @_;

    my $Data = {};

    # utf-8 client check
    if ( $Self->{ConfigObject}->Get('DefaultCharset') =~ /utf(\-8|8)/i ) {
        my $Check   = 'Failed';
        my $Message = 'No client_encoding found!';
        $Self->{DBObject}->Prepare( SQL => 'show all' );
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            if ( $Row[0] =~ /^client_encoding/i ) {
                $Message = "client_encoding found but it's set to '$Row[1]' (need to be UNICODE or UTF8)";
                if ( $Row[1] =~ /(UNICODE|utf(8|\-8))/i ) {
                    $Check   = 'OK';
                    $Message = "$Row[1]";
                }
            }
        }
        $Data = {
            Key         => 'utf8 client connection',
            Name        => 'Client Connection (utf8)',
            Description => 'Check the utf8 client connection.',
            Comment     => $Message,
            Check       => $Check,
        };
    }
    return $Data;
}

sub _VersionCheck {
    my ( $Self, %Param ) = @_;

    my $Data = {};

    # version check
    my $Check   = 'Failed';
    my $Message = 'No version found!';
    $Self->{DBObject}->Prepare( SQL => 'show all' );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        if ( $Row[0] =~ /^server_version/i ) {
            if ( $Row[1] =~ /^(\d{1,3}).*$/ ) {
                if ( $1 > 7 ) {
                    $Check   = 'OK';
                    $Message = "$Row[1]";
                }
                else {
                    $Check   = 'Failed';
                    $Message = "Its version $Row[1], you should use 8.x or higner.";
                }
            }
            else {
                $Check   = 'Failed';
                $Message = "Unkown version $Row[1]";
            }
        }
    }
    $Data = {
        Key         => 'version',
        Name        => 'Version',
        Description => 'Check database version.',
        Comment     => $Message,
        Check       => $Check,
    };
    return $Data;
}

1;
