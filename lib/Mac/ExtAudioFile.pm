package Mac::ExtAudioFile;
use strict;
use warnings;
use 5.010;
our $VERSION = "0.01";

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use Data::Validator;

sub set_client_data_format {
    my $self = shift;

    state $rule = Data::Validator->new(
        sample_rate    => 'Num',
        channels       => 'Int',
        bits           => 'Int',
        float          => { isa => 'Bool', optional => 1, xor => ['signed_integer'] },
        signed_integer => { isa => 'Bool', optional => 1, xor => ['float'] },
    );

    my $args = $rule->validate(@_);

    $self->_set_client_data_format(
        $args->{sample_rate},
        $args->{channels},
        $args->{bits},
        exists $args->{float} ? $args->{float} : 0,
        exists  $args->{signed_integer} ? $args->{signed_integer} : 0,
    );
}

1;
__END__

=head1 NAME

Mac::ExtAudioFile - It's new $module

=head1 SYNOPSIS

    use Mac::ExtAudioFile;

=head1 DESCRIPTION

Mac::ExtAudioFile is ...

=head1 LICENSE

Copyright (C) Daisuke Murase

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Daisuke Murase E<lt>typester@cpan.orgE<gt>

