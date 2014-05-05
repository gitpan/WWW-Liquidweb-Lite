package WWW::Liquidweb::Lite;

use 5.006;
use strict;
use warnings;

use WWW::Liquidweb::Lite::Error;

use LWP::UserAgent;
use JSON;
use Want;

our $VERSION = '0.01';

=head2 new

Create a new WWW::Liquidweb::Lite object

=head3 USAGE

This module builds the necessary tools to interact with the Liquidweb API from a JSON file that is
usually located at the following address:

	https://www.stormondemand.com/api/docs/v1/docs.json

This is built up in a way that slightly resembles WSDL, but the JSON structure is Liquidweb specific.

Example:
	my $liquidweb = WWW::Liquidweb::Lite->new(username => 'USERNAME', password => 'PASSWORD');

	ARGUMENT	DESCRIPTION
	---
	username	Liquidweb API username
	password	Liquidweb API password
	json		Location of the JSON describing the Liquidweb API
				[DEFAULTS: https://www.stormondemand.com/api/docs/v1/docs.json]
	timeout		LWP::UserAgent timeout
				[DEFAULTS: 60]
	json		Location of the JSON to build the API object
				[DEFAULTS: https://www.stormondemand.com/api/docs/v1/docs.json]
	version		Version of the API to use
				[DEFAULTS: v1]
	host		The "base" host for the API
				[DEFAULTS: https://api.stormondemand.com]
	---


=cut

sub new
{
	my $class  = shift;
	my $params = ref($_[0]) ? $_[0] : {@_};
	my $self   = {};

	unless ($params->{username} and $params->{password}) {
		return WWW::Liquidweb::Lite::Error->throw(
			type    => 'Missing Arguments',
			message => 'username and password are both required',
		);
	}

	$self->{__username} = $params->{username};
	$self->{__password} = $params->{password};

	$params->{host}    ||= 'https://api.stormondemand.com';
	$params->{json}    ||= 'https://www.stormondemand.com/api/docs/v1/docs.json';
	$params->{timeout} ||= 60;
	$params->{version} ||= 'v1';

	$self->{__host}     = $params->{host};
	$self->{__jsonUrl}  = $params->{json};
	$self->{__timeout}  = $params->{timeout};
	$self->{__version}  = $params->{version};


	$self->{__ua} = LWP::UserAgent->new;
	$self->{__ua}->agent("p5-www-liquidweb-lite/$VERSION");
	$self->{__ua}->timeout($self->{__timeout});

	my $req = HTTP::Request->new(POST => $self->{__jsonUrl});
	my $res = $self->{__ua}->request($req);

	unless ($res->is_success) {
		return WWW::Liquidweb::Lite::Error->throw(
			category => 'LWP::UserAgent',
			type     => $res->{_rc},
			message  => "$res->{_msg}$res->{_content}",
		);
	}

	bless($self, $class);
	$self->__build(decode_json($res->{_content}));

	return $self;
}

sub AUTOLOAD
{
	my $self = shift;

	our $AUTOLOAD;
	my ($key) = $AUTOLOAD =~ /.*::([\w_]+)/o;
	return if ($key eq 'DESTROY');

	push @{$self->{__chain}}, $key;

	my $args = ref($_[0]) ? $_[0] : {@_};

	if (want('OBJECT') || want('VOID')) {
		return $self;
	}

	my @chain = @{delete($self->{__chain})};

	my $code = pop(@chain);

	my $help;
	$help = 1 if ($code =~ /help/i);

	if ($help) {
		return $self->__help(@chain);
	} else {
		no strict qw(refs);

		@chain = map {ucfirst} @chain;
		my $package = join('::', @chain);

		unless (defined &{"WWW::Liquidweb::Lite::${package}::${code}"}) {
			return WWW::Liquidweb::Lite::Error->throw(
				type    => 'Invalid Method',
				message => "$package::$code is not a valid method",
			);
		}

		return &{"WWW::Liquidweb::Lite::${package}::${code}"}(
			{
				username => $self->{__username},
				password => $self->{__password},
				timeout  => $self->{__timeout},
				version  => $self->{__version},
				host     => $self->{__host},
			},
			$args,
		);
	}
}

sub __build
{
	my $self = shift;
	my $json = $self->{__json} = shift;

	no strict qw(refs);

	while (my ($namespace, $details) = each(%{$json})) {
		my $package = $namespace;
		$package =~ s{/}{::}g;
		for my $method (keys %{$details->{__methods}}) {
			*{"WWW::Liquidweb::Lite::${package}::${method}"}   = sub {__doRemoteApiCall("$namespace/$method", shift, shift)};
		}
	}
}

sub __doRemoteApiCall
{
	my $method = shift;
	my $params = shift;
	my $args   = shift || {};

	my $ua = LWP::UserAgent->new;
	$ua->timeout($params->{timeout});

	my $url = "$params->{host}/$params->{version}/$method.json";
	my $req = HTTP::Request->new(POST => $url);
	$req->authorization_basic($params->{username}, $params->{password});

	my $parser = JSON->new->utf8(1);
	my $json = $parser->encode({
		metadata => { ip => $ENV{REMOTE_ADDR} },
		params   => $args,
	});
	$req->content($json);

	my $response = $ua->request($req);

	my $code    = $response->code;
	my $content = $response->content;

	if ($code == 200) {
		my $results  = $parser->decode($content);
		return $results;
	}

	if ($content =~ /timeout/i) {
		my $timeout = $params->{timeout};
		return WWW::Liquidweb::Lite::Error->throw(
			category => 'HTTP::Request',
			type     => 'timeout',
			message  => "Request to $url timed out after $timeout seconds",
		);
	} elsif ($code == 401 || $code == 403) {
		return WWW::Liquidweb::Lite::Error->throw(
			category => 'HTTP::Request',
			type     => $code,
			message  => "Authorization failed for $url",
		);
	} elsif ($code == 500) {
		return WWW::Liquidweb::Lite::Error->throw(
			category => 'HTTP::Request',
			type     => $code,
			message  => "Request to $url failed due to a network error: $content",
		);
	} else {
		return WWW::Liquidweb::Lite::Error->throw(
			category => 'HTTP::Request',
			message  => "Request to $url failed: $content",
		);
	}
}

=head2 help

Get help with the Liquidweb API

=head3 USAGE

Calling the method 'help' at the end of your method API calls will return a hash of helpful information:

	my $server_list_help = $liquidweb->server->list->help;

In this example, $server_list_help will contain information about the 'Server/list' method in the Liquidweb API.

	$server_list_help->{__input}		This will contain a hash describing valid input parameters for this
						method.

	$server_list_help->{__description}	This will contain a string that will describe aspects of the method,
						and occasionally examples, insights, or other helpful information.

	$server_list_help->{__output}		This will contain a hash describing valid output that you may receive
						back from the API call.
=cut

sub __help
{
	my $self  = shift;
	my @chain = @_;

	my $method = pop(@chain);
	@chain = map {ucfirst} @chain;

	my $namespace = join('/', @chain);

	unless ($method && $namespace && $self->{__json}{$namespace}{__methods}{$method}) {
		return WWW::Liquidweb::Lite::Error->throw(
			type    => 'Invalid Arguments',
			message => 'Could not find documentation for given method, or did not receive a method.',
		);
	}

	return $self->{__json}{$namespace}{__methods}{$method};
}

=head1 NAME

WWW::Liquidweb::Lite - A module to interface with the Liquidweb API

=head1 SYNOPSIS

You can create an object in this manner:

	my $liquidweb = WWW::Liquidweb::Lite->new(username => "USERNAME", password => "PASSWORD");

USERNAME and PASSWORD correspond with the login credentials you would use for the Liquidweb API, as detailed here:

	http://www.liquidweb.com/StormServers/api/index.html

Once you have the object you can call a method from the api in "object fashion". For example:

	'Storm/Server/list'

Can be called from the object in this manner:

	$liquidweb->server->list

The casing does not have to be correct.

Arguments can be sent to the method as well:

	$liquidweb->server->list(category => 'Dedicated');

=head1 VERSION

Version 0.01

=cut

=head1 AUTHOR

Shane Utt, C<< <shaneutt at linux.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-WWW-Liquidweb-Lite at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Liquidweb-Lite>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

	perldoc WWW::Liquidweb::Lite

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Liquidweb-Lite>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Liquidweb-Lite>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Liquidweb-Lite>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Liquidweb-Lite/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014 Shane Utt, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1;
