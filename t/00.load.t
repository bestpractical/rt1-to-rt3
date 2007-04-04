use Test::More tests => 6;

BEGIN {
use_ok( 'RTx::Converter' );
use_ok( 'RTx::Converter::Config' );
use_ok( 'RTx::Converter::RT1' );
use_ok( 'RTx::Converter::RT1::Config' );
use_ok( 'RTx::Converter::RT3' );
use_ok( 'RTx::Converter::RT3::Config' );
}

diag( "Testing RTx::Converter $RTx::Converter::VERSION" );
