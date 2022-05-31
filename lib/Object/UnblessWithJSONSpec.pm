package Object::UnblessWithJSONSpec;
use strict;
use warnings;

use parent qw(Exporter);

our $VERSION = "0.01";

our @EXPORT_OK = qw(
    unbless_with_json_spec
);

use Scalar::Util qw(
    blessed
    reftype
);

use List::Util qw(
    any
);

use overload ();


use constant JSON_TYPE_ARRAYOF_CLASS => 'Cpanel::JSON::XS::Type::ArrayOf';
use constant JSON_TYPE_HASHOF_CLASS  => 'Cpanel::JSON::XS::Type::HashOf';
use constant JSON_TYPE_ANYOF_CLASS   => 'Cpanel::JSON::XS::Type::AnyOf';


sub unbless_with_json_spec {
    my ($object, $spec) = @_;

    return $object unless blessed($object);

    if (blessed $spec) {
        return resolve_json_type_arrayof($object, $spec) if $spec->isa(JSON_TYPE_ARRAYOF_CLASS);
        return resolve_json_type_hashof($object, $spec)  if $spec->isa(JSON_TYPE_HASHOF_CLASS);
        return resolve_json_type_anyof($object, $spec)   if $spec->isa(JSON_TYPE_ANYOF_CLASS);

        Carp::croak sprintf("'%s' object not supported spec", $spec);
    }

    if (my $ref = ref $spec) {
        return resolve_arrayref($object, $spec) if $ref eq 'ARRAY';
        return resolve_hashref($object, $spec)  if $ref eq 'HASH';

        Carp::croak sprintf("'%s' reference not supported spec", $spec);
    }

    return $object;
}


sub list {
    my ($object) = @_;

    if (my $to_list = overload::Method($object,'@{}')) {
        return $to_list->($object);
    }

    if ($object->can('next')) {
        my @list;
        while (defined (my $v = $object->next)) {
            push @list => $v;
        }
        return \@list;
    }

    Carp::croak sprintf("'%s' object could not be converted to array ref", $object);
}


sub available_array {
    my ($object) = @_;
    my $f = overload::Method($object, '@{}') || $object->can('next');
    return !!$f
}


sub available_hash {
    my ($object) = @_;
    my $f = $object->can('JSON_KEYS');
    return !!$f;
}


sub resolve_arrayref {
    my ($object, $spec) = @_;

    my @data;
    my $list = list($object);
    for my $i (0 .. $#$spec) {
        my $v = $list->[$i];
        my $s = $spec->[$i];
        push @data => unbless_with_json_spec($v, $s);
    }
    return \@data;
}


sub resolve_hashref {
    my ($object, $spec) = @_;

    my %data;
    for my $key (keys %$spec) {
        my $v = $object->$key;
        my $s = $spec->{$key};
        $data{$key} = unbless_with_json_spec($v, $s)
    }
    return \%data;
}


sub resolve_json_type_arrayof {
    my ($object, $spec) = @_;

    my $s = $$spec;

    my @data;
    my $list = list($object);
    for my $v (@$list) {
        push @data => unbless_with_json_spec($v, $s);
    }
    return \@data;
}


sub resolve_json_type_hashof {
    my ($object, $spec) = @_;

    my $s = $$spec;

    if ($object->can('JSON_KEYS')) {
        my %data;
        for my $key ($object->JSON_KEYS) {
            my $v = $object->$key;
            $data{$key} = unbless_with_json_spec($v, $s)
        }
        return \%data;
    }
    else {
        Carp::croak sprintf("'%s' object could not call JSON_KEYS method", $object);
    }
}


sub resolve_json_type_anyof {
    my ($object, $spec) = @_;

    my $s = available_array($object) ? $spec->[1]
          : available_hash($object)  ? $spec->[2]
          : $spec->[0];

    return unbless_with_json_spec($object, $s);
}

1;
__END__

=encoding utf-8

=head1 NAME

Object::UnblessWithJSONSpec - unbless object using JSON spec like Cpanel::JSON::XS::Type

=head1 SYNOPSIS

    use Object::UnblessWithJSONSpec qw(unbless_with_json_spec);

    use Cpanel::JSON::XS::Type;

    {
        package SomeEntity;
        sub new {
            my ($class, %args) = @_;
            return bless \%args, $class
        }
        sub a { shift->{a} }
        sub b { shift->{b} }
    }

    my $entity = SomeEntity->new(a => 123, b => 'HELLO');

    unbless_with_json_spec($entity, { a => JSON_TYPE_INT });
    # => { a => 123 }

    unbless_with_json_spec($entity, { b => JSON_TYPE_STRING });
    # => { b => 'HELLO' }

    unbless_with_json_spec($entity, { a => JSON_TYPE_INT, b => JSON_TYPE_STRING });
    # => { a => 123, b => 'HELLO' }


=head1 DESCRIPTION

Object::UnblessWithJSONSpec is designed to assist with JSON encode.
For example, an blessed object can be encoded using JSON spec:

    use Cpanel::JSON::XS ();
    use Scalar::Util qw(blessed);

    my $json = Cpanel::JSON::XS->new->canonical;
    sub encode_json {
        my ($data, $spec) = @_;

        $data = unbless_with_json_spec($data, $spec) if blessed $data;
        $json->encode($data, $spec)
    }

    encode_json($entity, { a => JSON_TYPE_INT });
    # => {"a":123}

    encode_json($entity, { b => JSON_TYPE_STRING });
    # => {"b":"HELLO"}

    encode_json($entity, { a => JSON_TYPE_INT, b => JSON_TYPE_STRING }),
    # => {"a":123,"b":"HELLO"}


=head1 LICENSE

Copyright (C) kfly8.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kfly8 E<lt>kfly@cpan.orgE<gt>

=cut

