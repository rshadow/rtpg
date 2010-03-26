use warnings;
use strict;
use utf8;
use open ':utf8';

=head1 Template

Модуль шаблонов

=cut

package RTPG::WWW::Template;
use base qw(Template);

use CGI;
use Encode qw(is_utf8 decode encode);

use RTPG;
use RTPG::WWW::Config;
use RTPG::WWW::Locale qw(gettext);

sub new
{
    my $class = shift;

    # Set human values functions to use in templates
    $Template::Stash::SCALAR_OPS->{as_human_size}   =
    $Template::Stash::LIST_OPS->{as_human_size}     = sub {
        my ($digit, $letter, $byte) = RTPG::as_human_size(shift);
        return $digit . gettext($letter) . gettext($byte) if $digit;
        return 0;
    };
    $Template::Stash::SCALAR_OPS->{as_human_speed}  =
    $Template::Stash::LIST_OPS->{as_human_speed}    = sub {
        my ($digit, $letter, $byte, $div, $time) = RTPG::as_human_speed(shift);
        return $digit . gettext($letter) . gettext($byte) .
            gettext($div). gettext($time)
                if $digit;
        return 0;
    };
    $Template::Stash::SCALAR_OPS->{as_human_datetime} =
    $Template::Stash::LIST_OPS->{as_human_datetime} = sub {
        return RTPG::as_human_datetime(shift);
    };

    # Other functions
    $Template::Stash::SCALAR_OPS->{ucfirst} = sub { return ucfirst shift };

    # Debug function
    $Template::Stash::ROOT_OPS->{dump} =
    $Template::Stash::SCALAR_OPS->{dump} =
    $Template::Stash::HASH_OPS->{dump} =
    $Template::Stash::LIST_OPS->{dump} = sub {'###'.Dumper(@_).'###'};

    my %opts = (
        RELATIVE        => 1,
        ABSOLUTE        => 1,
        RECURSION       => 1,
        INCLUDE_PATH    => cfg->{dir}{skin}{current} . ':' .
                           cfg->{dir}{templates}  . ':' .
                           cfg->{dir}{skin}{default},
#        PRE_CHOMP       => 1,
#        POST_CHOMP      => 1,
#        TRIM            => 1,
        ENCODING        => 'utf8',
        WRAPPER         => 'main.tt.html',
        @_
    );

    # Enable template toolkit cache
    if( defined cfg->get('cache') and -d cfg->get('cache') )
    {
        $opts{COMPILE_EXT} = '.ttc';
        $opts{COMPILE_DIR} = cfg->get('cache');
    }

    my $obj = $class->SUPER::new( %opts );
    return $obj;
}

=head2 process

Output template.

=cut

sub process
{
    my ($self, $template, $opts) = @_;

    $opts = {} if !defined $opts or !%$opts;

    # Get output ###############################################################
    my ($header, $output) = ('', '');

    # Get header
    $header = CGI->new->header(
        -charset        => 'utf-8',
        -type           => 'text/html',
        -Cache_Control  => 'no-cache, no-store, max-age=0, must-revalidate',
        -expires        => 'now',
        (cfg->cookies)  ? (-cookie => cfg->cookies)
                        : (),
    );

    # Add common params
    $opts = {
        common   => { },
        config   => cfg(),
        gettext  => sub { return gettext(@_);                    },
        langs    => sub { return RTPG::WWW::Locale::aviable();   },
        skins    => sub { return cfg->skins();                   },
        %$opts
    };

    # Get body
    $self->SUPER::process($template, $opts, \$output);

    # Load error page if error
    if( $self->error() )
    {
        # Change to error page
        $template = 'error.tt.html';

        # If template not found return 404 status
        if( $self->error() =~ m/^file error - .* not found$/ )
        {
            $opts->{error} = {
                message => gettext('File not found'),
                status => 404
            };
        }
        # Get error message
        else
        {
            $opts->{error} = { message => $self->error(), status => 503 };
        }

        # Get error page body or error message only if Template not work
        $self->SUPER::process($template, $opts, \$output);
        $output .= $self->error() if $self->error();
    }

    # Be shure output is utf8
    $output = decode( utf8 => $output ) unless is_utf8 $output;

    # Output ###################################################################
    print $header;
    print $output;
}

1;
