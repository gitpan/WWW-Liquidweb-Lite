package WWW::Liquidweb::Lite::Error;

use 5.006;
use strict;
use warnings FATAL => 'all';

use Devel::StackTrace;

=head1 NAME

WWW::Liquidweb::Lite::Error - Error handling for WWW::Liquidweb::Lite

=head1 SUBROUTINES/METHODS

=head2 new

Returns an error object

=head3 USAGE

	ARGUMENT	DESCRIPTION
	---
	type		Describes the variety of failure occurred. Potential
			values could be 'perl error', or basic http error
			codes such as '404', '500', e.t.c.
				[DEFAULTS: 'fail']

	category	Describes what actually failed. Potential values
			could be 'http request', 'http auth', or something
			specific to your application like 'foobar api error'.
				[DEFAULTS: 'object' (assumes something is wrong with
				WWW::Liquidweb::Lite unless told otherwise)]

	message		Describes the specifics of what actually occurred for
			a user to read.
				[DEFAULTS: 'unknown']
	---

=cut

sub new
{
	my $class = shift;
	my %args = ref($_[0]) ? %{$_[0]} : @_;
	$args{type}     = $args{type}     ? $args{type}     : 'fail';
	$args{category} = $args{category} ? $args{category} : 'object';
	$args{message}  = $args{message}  ? $args{message}  : 'unknown';
	my $self  = {
		error_type     => $args{type},
		error_category => $args{category},
		error_message  => $args{message},
	};
	return bless($self, $class);
}

=head2 category

Helper method to retrieve or set the error category.

=cut

sub category
{
	my $self     = shift;
	my $category = shift;

	if ($category) {
		$self->{error_category} = $category;
	}

	return $self->{error_category};
}

=head2 message

Helper method to retrieve or set the error message.

=cut

sub message
{
	my $self    = shift;
	my $message = shift;

	if ($message) {
		$self->{error_message} = $message;
	}

	return $self->{error_message};
}

=head2 type

Helper method to retrieve or set the error type.

=cut

sub type
{
	my $self    = shift;
	my $type = shift;

	if ($type) {
		$self->{error_type} = $type;
	}

	return $self->{error_type};
}

=head2 throw

Die, put a stack trace into the object, and return it.

=head3 USAGE

Forwards to new.

	ARGUMENT	DESCRIPTION
	---
	type		Describes the variety of failure occurred. Potential
			values could be 'perl error', or basic http error
			codes such as '404', '500', e.t.c.
				[DEFAULTS: 'fail']

	category	Describes what actually failed. Potential values
			could be 'http request', 'http auth', or something
			specific to your application like 'foobar api error'.
				[DEFAULTS: 'object' (assumes something is wrong with
				WWW::Liquidweb::Lite unless told otherwise)]

	message		Describes the specifics of what actually occurred for
			a user to read.
				[DEFAULTS: 'unknown']
	---

=cut

sub throw
{
	my $object = shift;
	my $error  = $object->new(@_);
	$error->{stack_trace} = Devel::StackTrace->new;
	die $error;
}

1;
