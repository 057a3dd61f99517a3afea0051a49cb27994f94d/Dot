use Dot 'sane', iautoload => ['Test::More'];

sub mod {
	my $o = shift;
	$o->{'=='} = sub { 12 };
	bless $o, 'Dot::Overload';
}
my $o = mod({});
ok(($o == 0) == 12);
done_testing();
