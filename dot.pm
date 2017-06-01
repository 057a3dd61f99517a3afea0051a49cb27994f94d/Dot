#   Dot - A new object system for Perl
#   Copyright © 2018 Yang Bo
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.
package dot;
use warnings;
use strict;
sub add {
	my $h = shift;
	while (@_) {
		my ($k, $v) = splice @_, 0, 2;
		$h->{$k} = $v;
	}
}
sub new {
	my $h;
	$h = {new => \&new,
	      add => sub {
		      add($h, @_);
	      },
	      evolve => sub {
		      my ($cref, @arg) = @_;
		      my $from = $h->{new};
		      $h->{new} = sub {
			      my $o = $from->();
			      $o->{evolve}($cref, @arg);
			      $o;
		      };
		      $cref->($h, @arg);
	      }};
}
1;
