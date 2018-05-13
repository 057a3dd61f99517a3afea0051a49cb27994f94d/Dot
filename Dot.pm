#   Dot - The beginning of a Perl universe
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
package Dot;

use strict;
use warnings qw/all FATAL uninitialized/;
use feature qw/state say/;

BEGIN {
	no strict 'refs';
	my @H = ($^H, ${^WARNING_BITS}, %^H);
	sub import {
		my $ns = caller . '::';
		shift;
		while (@_) {
			my $q = shift;
			if ($q eq 'iautoload') {
				my (@pkg, %map, @l);
				for (@{+shift}) {
					my ($p, @f) = ref() ? @$_ : $_;
					push @pkg, $p;
					for (@f) {
						push @l, $ns . $_ if s/^0//;
						$map{$_} = $p;
					}
				}
				my $i = 1;
				*{$ns . 'AUTOLOAD'} = sub {
					# "fully qualified name of the original subroutine".
					my $q = our $AUTOLOAD;
					# to avoid possibly overwrite @_ by successful regular expression match.
					my ($f) = do { $q =~ /.*::(.*)/ };
					for my $p ($map{$f} || @pkg) {
						#   calculate the actual file to be loaded thus avoid eval and
						# checking $@ mannually.
						do { require $p =~ s|::|/|gr . '.pm' };
						if (my $r = *{"${p}::$f"}{CODE}) {
							no warnings 'prototype';
							*$q = $r;
							# TODO: understand why using goto will lost context.
							#goto &$r;
							return $i ? undef : &$r;
						}
					}
					confess("unable to autoload $q.");
				};
				$_->() for @l;
				$i = 0;
			} elsif ($q eq 'oautoload') {
				for my $p (@{+shift}) {
					my $r = $p =~ s|::|/|gr . '.pm';
					# ignore already loaded module.
					my $f = "${p}::AUTOLOAD";
					next if $INC{$r} or *$f{CODE};
					*$f = sub {
						my ($f) = do { our $AUTOLOAD =~ /.*::(.*)/ };
						my $symtab = *{"${p}::"}{HASH};
						delete $symtab->{AUTOLOAD};
						require $r;
						&{$symtab->{$f}};
					};
				}
			} elsif ($q eq 'sane') {
				($^H, ${^WARNING_BITS}, %^H) = @H;
			} else {
				confess("unknown request $q");
			}
		}
	}
}
Dot->import(iautoload => [[qw/Scalar::Util weaken/],
			  [qw/Carp confess/]]);
sub add {
	my $o = shift;
	while (@_) {
		my ($k, $v) = splice @_, 0, 2;
		$o->{$k} = $v;
	}
}
sub mod {
	my $o = shift;
	weaken($o);
	add($o,
	    weaken => \&weaken,
	    add => sub {
		    unshift @_, $o;
		    goto &add;
	    },
	    del => sub {
		    map { $_ => delete $o->{$_} } @_;
	    });
	$o;
}
1;
