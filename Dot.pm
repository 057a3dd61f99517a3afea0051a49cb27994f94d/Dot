#   Dot - The beginning of a Perl universe
#   Copyright © 2018-2022 Yang Bo
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

our $VERSION = 'v1.0.1';

use strict;
use warnings qw/all FATAL uninitialized/;
use feature qw/state say/;

sub _require ($) {
	my $r = shift =~ s|::|/|gr . '.pm';
	require $r if not $INC{$r};
}
sub flatten (;$) {
	my $v = @_ ? shift : $_;
	ref $v eq 'ARRAY' ? @$v : $v;
}
BEGIN {
	no strict 'refs';
	my @H = ($^H, ${^WARNING_BITS}, %^H);
	sub import {
		my $ns = caller . '::';
		shift;
		while (@_) {
			my $q = shift;
			if ($q eq 'iautoload') {
				my (@pkg, %map);
				for (@{+shift}) {
					my ($p, @f) = flatten;
					push @pkg, $p;
					for (@f) {
						my ($from, $to) = flatten;
						$from =~ s/^([$@%&*])//;
						$to ||= $from;
						if (my $s = $1) {
							state $sigil = {'$' => 'SCALAR',
									'@' => 'ARRAY',
									'%' => 'HASH',
									'&' => 'CODE',
									'*' => 'GLOB'};
							_require $p;
							*{$ns . $to} = *{"${p}::$from"}{$sigil->{$s}};
						} else {
							$map{$to} = {from => $from,
								     module => $p};
						}
					}
				}
				*{$ns . 'AUTOLOAD'} = sub {
					# "fully qualified name of the original subroutine".
					my $q = our $AUTOLOAD;
					# to avoid possibly overwrite @_ by successful regular expression match.
					my ($to) = do { $q =~ /.*::(.*)/ };
					my $u = $map{$to};
					my $from = $u->{from} || $to;
					for my $p ($u->{module} || @pkg) {
						#   calculate the actual file to be loaded thus avoid eval and
						# checking $@ mannually.
						_require $p;
						if (my $r = *{"${p}::$from"}{CODE}) {
							no warnings 'prototype';
							*$q = $r;
							# TODO: understand why using goto will lost context.
							#goto &$r;
							return &$r;
						}
					}
					confess("unable to autoload $q.");
				};
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
for my $tie (map { "tie$_" } qw/hash array handle scalar/) {
	no strict 'refs';
	*{uc $tie} = sub {
		bless pop, shift;
	};
}
for my $f (qw/binmode clear close delete destroy eof exists extend fetch fetchsize
	   fileno firstkey getc nextkey open pop print printf push read
	   readline scalar seek shift splice store storesize tell unshift
	   untie write/) {
	no strict 'refs';
	*{uc $f} = sub {
		if ($f ne 'destroy') {
			goto &{shift->{$f}};
		} else {
			if (my $subr = shift->{$f}) {
				goto &$subr;
			}
		}
	};
}

require overload;
overload->import(#
		 nomethod => sub {
			 my $o = shift;
			 my $op = pop;
			 if (my $r = $o->{$op})	{ goto &$r }
			 else			{ die "$op not defined" }
		 });

1;
