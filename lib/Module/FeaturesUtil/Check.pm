package Module::FeaturesUtil::Check;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(
                       check_feature_set_spec
                       check_features_decl
               );

our %SPEC;

$SPEC{check_feature_set_spec} = {
    v => 1.1,
    summary => 'Check feature set specification',
    args => {
        feature_set_spec => {
            schema => 'hash*',
            req => 1,
            pos => 0,
        },
    },
    args_as => 'array',
};
sub check_feature_set_spec {
    require Data::Sah;
    require Hash::DefHash;

    my $spec = shift;

    my $dh;
    eval { $dh = Hash::DefHash->new($spec) }
        or return [500, "Spec is not a valid defhash: $@"];
    ref $spec->{features} eq 'HASH'
        or return [500, "Features properties is not defined or not a hash"];

    for my $fname (sort keys %{ $spec->{features} }) {
        $fname =~ /\A\w+\z/
            or return [500, "Feature name '$fname' is invalid, please only use /\\w+/"];
        my $fspec = $spec->{features}{$fname};
        eval { $dh = Hash::DefHash->new($fspec) }
            or return [500, "Spec for feature '$fname' is not a valid defhash: $@"];
        if ($fspec->{schema}) {
            eval { Data::Sah::gen_validator($fspec->{schema}) }
                or return [500, "Schema for feature '$fname' is invalid: $@"];
        }
    } # for fname
    [200];
}

$SPEC{check_features_decl} = {
    v => 1.1,
    summary => 'Check features declaration',
    args => {
        features => {
            schema => 'hash*',
            req => 1,
            pos => 0,
        },
    },
    args_as => 'array',
};
sub check_features_decl {
    require Data::Sah;
    require Hash::DefHash;

    my $features = shift;

    ref $features eq 'HASH'
        or return [500, "Features is not a hash"];

    for my $fsetname (sort keys %$features) {
        $fsetname =~ /\A\w+(::\w+)*\z/
            or return [500, "Feature set name '$fsetname' is invalid, please use regular Perl namespace e.g. Foo::Bar"];

        # retrieve feature set spec from definer module
        my $mod = "Module::Features::$fsetname";
        (my $modpm = "$mod.pm") =~ s!::!/!g;
        eval { require $modpm; 1 }
            or return [500, "Cannot get specification for feature set '$fsetname': Cannot load $mod: $@"];
        my $spec = \%{"$mod\::FEATURES_DEF"};
        my $res = check_feature_set_spec($spec);
        $res->[0] == 200
            or return [500, "Specification for feature set '$fsetname' is invalid: $res->[1]"];

        my $set_features = $features->{$fsetname};
        ref $features eq 'HASH'
            or return [500, "Features for set '$fsetname' is not a hash"];

        # check required features
        for my $fname (sort keys %{ $spec->{features} }) {
            my $fspec = $spec->{features}{$fname};
            next unless $fspec->{req};
            exists $set_features->{$fname}
                or return [500, "Missing declaration of required feature '$fname' in set '$fsetname'"];
        }

        for my $fname (sort keys %$set_features) {
            my $fspec = $spec->{features}{$fname}
                or return [500, "Feature '$fname' is unknown in set '$fsetname'"];

            my $fschema = $fspec->{schema};
            if ($fschema) {
                my $vdr = Data::Sah::gen_validator($fschema, {return_type=>'str_errmsg+val'});
                my $fvalue = $set_features->{$fname};
                $fvalue = ref $fvalue eq 'HASH' ? $fvalue->{value} : $fvalue;
                my $res = $vdr->($fvalue);
                !$res->[0]
                    or return [500, "Invalid value for feature '$fname' in set '$fsetname': $res->[0]"];
            }
        } # for fname
    } # for fsetname
    [200];
}

1;
# ABSTRACT: Check feature set specification and feature declaration

=head1 DESCRIPTION


=head1 SEE ALSO

L<Module::Features>
