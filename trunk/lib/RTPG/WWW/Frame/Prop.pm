use warnings;
use strict;
use utf8;

=head1 NAME

RTPG::WWW::Frame::Prop

=cut

package RTPG::WWW::Frame::Prop;

use RTPG;
use RTPG::WWW::Config;
use RTPG::WWW::Locale;

=head2 new

Get params

=cut

sub new
{
    my ($class, %opts) = @_;

    # Get current state
    $opts{$_} = cfg->get($_) for qw(current prop do);
    $opts{prop} ||= 'info';
    # Get selected files indexes
    my @index = cfg->get('index[]');
    $opts{index} = {};
    $opts{index} = { map {$_ => 'checked'} @index } if @index;
    # Get selected folder indexes
    my @folder = cfg->get('folder[]');
    $opts{folder} = {};
    $opts{folder} = { map { $_ => 'checked' } @folder } if @folder;

    {
        # Exit if no current selected
        last unless $opts{current};

        # Get RTPG object
        my $rtpg = RTPG->new(url => cfg->get('rpc_uri'));
        my $error;

        # Check exists current
        ($opts{info}, $error) = $rtpg->torrent_info( $opts{current} );
        if( $error )
        {
            # Drop current if not in list
            cfg->set('current', '');
            $opts{current} = '';
            last;
        }

        # Get info by page name
        if( $opts{prop} eq 'info')
        {
            # Count space for future downloads. And set warning flag in no space
            my $need = 0;
            $need += ($_->{size_bytes} - $_->{left_bytes}) for @{ $opts{list} };
            $opts{info}{low_space} = $need - $opts{info}{free_diskspace}
                if $need > $opts{info}{free_diskspace};
        }
        elsif($opts{prop} eq 'peers')
        {
            my ($error);
            ($opts{list}, $error) = $rtpg->peer_list( $opts{current} );
            $opts{error} ||= $error;

            if( cfg->is_geo_ip and eval "require Geo::IPfree" and !$@)
            {
                my $geo = Geo::IPfree->new;
                $geo->Faster;
                ($_->{country_code}, $_->{country_name},) =
                    $geo->LookUp( $_->{address} )
                        for @{ $opts{list} };
            }
        }
        elsif($opts{prop} eq 'files')
        {
            # If priority command then get priority level
            if($opts{do} =~ m/^(off|low|normal|high)$/i)
            {
                $opts{param} = RTPG::file_priority_num( $opts{do} );
                $opts{do}       = 'priority';
            }
            # Set priorities
            if( $opts{do} eq 'priority' and %{ $opts{index} } )
            {
                $rtpg->set_file_priority($opts{current}, $_, $opts{param})
                    for keys %{ $opts{index} };
            }

            ($opts{list}, $opts{error}) = $rtpg->file_list( $opts{current} );

            # Tree view simle for HTML usage
            my @tree;
            # Current path for circle
            my @g_path;
            # Index for files operations
            my ($index, $dir_index, $thru_index, $parent_index) = (0, 0, 0, 0);
            my $last_level = 0;

            for my $file ( @{ $opts{list} } )
            {
                # Get current file components
                my @path        = @{ $file->{path_components} };
                my $filename    = pop @path;

                # Make catalog and left padding
                for(my $level = 0; $level < @path; $level++)
                {
                    # For new path, drop deep catalog and add new path
                    if( !exists $g_path[$level] or
                        $path[$level] ne $g_path[$level] )
                    {
                        @g_path = splice @g_path,0, $level+1;

                        # Drop parent if in root
                        $parent_index = 0  unless $level;

                        # Add directory in tree
                        my %node = (
                            level       => $level,
                            name        => $path[$level],
                            type        => 'dir',
                            'index'     => $dir_index++,
                            thru_index  => ++$thru_index,
                            parent_index => $parent_index,
                        );
                        push @tree, \%node;

                        $parent_index = $thru_index;
                    }
                }

                # Move to path
                @g_path = @path;
                # Drop parent if in root
                $parent_index = 0  unless scalar(@path);

                # Add file in tree
                my %node = (
                    level       => scalar(@path),
                    name        => $filename,
                    type        => 'file',
                    data        => $file,
                    'index'     => $index++,
                    thru_index  => ++$thru_index,
                    parent_index => $parent_index,
                );
                $node{complete} = 1 if $file->{percent} eq '100%';
                $node{dlink} = cfg->get('direct_link') . $file->{path}
                    if cfg->get('direct_link') and $node{complete} and
                       $opts{info}{complete};

                push @tree, \%node;
#DieDumper \@tree, \@g_path, \@path, $filename if $filename =~ m{\.pdf};
            }

            $opts{tree} = \@tree;
        }
        elsif($opts{prop} eq 'trackers')
        {
            ($opts{info}, $opts{error}) = $rtpg->tracker_list( $opts{current} );
        }
        elsif($opts{prop} eq 'chunks')
        {
        }
        elsif($opts{prop} eq 'transfer')
        {
        }
        else
        {
            $opts{error} = RTPG::WWW::Locale::gettext('Unknown property page');
        }
    }

    my $self = bless \%opts, $class;

    return $self;
}

1;
