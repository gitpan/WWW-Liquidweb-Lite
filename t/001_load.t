use Test::More tests => 2;

BEGIN{use_ok( 'WWW::Liquidweb::Lite' );}

my $object = WWW::Liquidweb::Lite->new(username => 'test', password => 'test');
isa_ok($object, 'WWW::Liquidweb::Lite');