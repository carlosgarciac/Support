# --
# Kernel/System/Support/Database/db2.pm - all required system information
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Support::Database::db2;
## nofilter(TidyAll::Plugin::OTRS::Perl::LayoutObject)

use strict;
use warnings;

use Kernel::System::XML;
use Kernel::System::Time;

use vars qw(@ISA $VERSION);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(ConfigObject LogObject MainObject DBObject EncodeObject LayoutObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    # create additional objects
    $Self->{XMLObject}      = Kernel::System::XML->new( %{$Self} );
    $Self->{TimeObject}     = Kernel::System::Time->new( %{$Self} );
    $Self->{LanguageObject} = $Self->{LayoutObject}->{LanguageObject};

    return $Self;
}

sub AdminChecksGet {
    my ( $Self, %Param ) = @_;

    # get names of available checks from sysconfig
    my $Checks = $Self->{ConfigObject}->Get('Support::Database::DB2');

    # find out which checks should are enabled in sysconfig
    my @EnabledCheckFunctions;
    if ( $Checks && ref $Checks eq 'HASH' ) {

        # get all enabled check function names
        @EnabledCheckFunctions = sort grep { $Checks->{$_} } keys %{$Checks};
    }

    # to store the result
    my @DataArray;

    FUNCTIONNAME:
    for my $FunctionName (@EnabledCheckFunctions) {

        # prepend an underscore
        $FunctionName = '_' . $FunctionName;

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
        if ( open( $In, '<', $File ) ) {    ## no critic
            while (<$In>) {
                $Content .= $_;
            }
            close($In);
            my @XMLHash = $Self->{XMLObject}->XMLParse2XMLHash( String => $Content );
            for my $Table ( @{ $XMLHash[1]->{database}->[1]->{Table} } ) {
                if ($Table) {
                    $Count++;
                    if (
                        $Self->{DBObject}->Prepare(
                            SQL   => "select * from $Table->{Name}",
                            Limit => 1
                        )
                        )
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
                $Message = $Self->{LanguageObject}->Get("Table doesn't exist") . ": $Message";
            }
            else {
                $Check   = 'OK';
                $Message = "$Count " . $Self->{LanguageObject}->Get('tables.');
            }
            $Data = {
                Name        => $Self->{LanguageObject}->Get('Table Check'),
                Description => $Self->{LanguageObject}->Get('Check existing framework tables.'),
                Comment     => $Message,
                Check       => $Check,
            };
        }
        else {
            $Data = {
                Name        => $Self->{LanguageObject}->Get('Table Check'),
                Description => $Self->{LanguageObject}->Get('Check existing framework tables.'),
                Comment     => $Self->{LanguageObject}->Get("Can't open file") . " $File: $!",
                Check       => 'Critical',
            };
        }
    }
    else {
        $Data = {
            Name        => $Self->{LanguageObject}->Get('Table Check'),
            Description => $Self->{LanguageObject}->Get('Check existing framework tables.'),
            Comment     => $Self->{LanguageObject}->Get("Can't find file") . " $File!",
            Check       => 'Critical',
        };
    }
    return $Data;
}

sub _CurrentTimestampCheck {
    my ( $Self, %Param ) = @_;
    my $Data   = {};
    my $DbTime = '';

    # Current Timestamp check
    my $Check   = '';
    my $Message = '';
    $Self->{DBObject}->Prepare( SQL => "SELECT current_timestamp" );
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $DbTime = $Row[0];
    }
    my $TimeApplicationServer = $Self->{TimeObject}->SystemTime();
    my $TimeDatabaseServer    = $Self->{TimeObject}->TimeStamp2SystemTime(
        String => $DbTime,
    );

    my $TimeDifference = 0;
    my $Range          = 10;
    $TimeDifference = $TimeApplicationServer - $TimeDatabaseServer;
    if ( ( $TimeDifference >= ( $Range * -1 ) ) && ( $TimeDifference <= $Range ) ) {
        $Check = 'OK';
        $Message
            = $Self->{LanguageObject}->Get(
            'There is no difference between application server time and database server time.'
            );
    }
    else {
        $Check = 'Failed';
        $Message
            = $Self->{LanguageObject}->Get('There is a material difference (')
            . $TimeDifference
            . $Self->{LanguageObject}->Get(' seconds) between application server (')
            . $TimeApplicationServer . $Self->{LanguageObject}->Get(') and database server (')
            . $TimeDatabaseServer . $Self->{LanguageObject}->Get(') time.');
    }

    $Data = {
        Name        => $Self->{LanguageObject}->Get('Current Timestamp Check'),
        Description => $Self->{LanguageObject}->Get('Check "System Time" vs "Current Timestamp".'),
        Comment     => $Message,
        Check       => $Check,
    };
    return $Data;
}
1;
