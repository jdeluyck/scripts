#
# yaiaways.pl - Yet Another Irssi Away Script - by Jan De Luyck
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2
# of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.2";

%IRSSI = (
	  authors     => 'Jan De Luyck',
	  contact     => 'jan@kcore.org',
	  name        => 'yaiaways.pl',
	  description => 'Yet another away script, based on Away, with reason and nick suffix, and restores the old nick. Supports multiple servers.',
	  license     => 'GPLv2',
          url         => 'http://www.kcore.org/?menumain=3&menusub=6',
	  changed     => 'Sun May 22 10:42:22 CEST 2005',
);

Irssi::theme_register([
	'yaiaways_loaded', '%R>>%n %_Scriptinfo:%_ Loaded $0 v$1 - by $2.'
]);

# /SET
#
#	away_reason		if you are not away and type /AWAY without
#				arguments, this string will be used as
#				your away reason
#
#   away_ nick_suffix		The nick suffix to use. set to '' for none.
#

my $doing_away=0;
my %oldnicks;

sub proc_away {
	my ($args) = @_; #, $server, $item) = @_;

	if ($doing_away == 1)
	{
		$doing_away = 0;
	}
	else
	{

		my $server;
		my @servers = Irssi::servers();
	
		foreach $server (@servers)
		{
			if ($server)
			{
				if (!$server->{usermode_away})
				{
					$doing_away = 1;

					#store the old nick
					$oldnicks{$server->{tag}} = $server->{nick};
					
					$server->command ("nick " . $server->{nick} . Irssi::settings_get_str("away_nick_suffix"));

					my $reason = Irssi::settings_get_str("away_reason");

					if (defined($args) && length($args) != 0) 
					{
						$reason = $args;
					}
		
					$server->command("AWAY " . $reason);
					Irssi::signal_stop();
				}
				else
				{
					$doing_away = 1;			
		
					$server->command("nick " . $oldnicks{$server->{tag}});
					delete($oldnicks{$server->{tag}});
				
					$server->command("AWAY");
					Irssi::signal_stop();
				}
			}
		}
	}
}

Irssi::settings_add_str("yaiaways", "away_reason", "Away from keyboard");
Irssi::settings_add_str("yaiaways", "away_nick_suffix", "[afk]");

Irssi::command_bind("away", "proc_away");

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'yaiaways_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors});
