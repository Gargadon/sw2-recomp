#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
generated_dir=${1:-"$script_dir/generated/sw2xl_us"}
marker='DEFINE_REX_FUNC(sub_8819C710)'
module_registry="$script_dir/generated/default/module_registry.cpp"

source_file=$(grep -rlm1 --include='*_recomp.*.cpp' -F "$marker" "$generated_dir" 2>/dev/null | head -n 1 || true)
[[ -n "$source_file" ]] || { echo "Could not find $marker under $generated_dir." >&2; exit 1; }

perl -0777 -i -pe '
    my $marker = "DEFINE_REX_FUNC(sub_8819C710)";
    my @labels = qw(loc_8819C760 sub_8819C798 sub_88198C98 sub_8819F6D8 sub_8819F710 sub_8819D528 sub_8819AD00 sub_881A4040 sub_8819C7D0);
    my $start = index($_, $marker);
    my $end = index($_, "DEFINE_REX_FUNC(", $start + length($marker));
    $end = length($_) if $end < 0;
    my $function = substr($_, $start, $end - $start);
    my $changed = 0;
    for my $index (1 .. $#labels) {
        my $old = "case ${index}:\n\t\t$labels[$index]";
        my $scaled = $index * 4;
        my $new = "case ${scaled}:\n\t\t$labels[$index]";
        next if index($function, $new) >= 0;
        die "The XL switch case for $labels[$index] no longer matches the expected output.\n"
            if index($function, $old) < 0;
        $function =~ s/\Q$old\E/$new/;
        $changed = 1;
    }
    substr($_, $start, $end - $start, $function) if $changed;
    print STDERR "Scaled XL dispatch cases at guest address 0x8819C758.\n" if $changed;
' "$source_file"

# On Linux, dlopen does not add the lib prefix or .so suffix for a bare
# module name. Register the colocated XL host with its exact relative path.
[[ -f "$module_registry" ]] || {
    echo "Could not find generated module registry: $module_registry" >&2
    exit 1
}
if ! grep -Fq '"./libsamurai_warriors_2_SW2XL_US.so"' "$module_registry"; then
    perl -0pi -e 's/"samurai_warriors_2_SW2XL_US"\);/".\/libsamurai_warriors_2_SW2XL_US.so"\);/' \
        "$module_registry"
    grep -Fq '"./libsamurai_warriors_2_SW2XL_US.so"' "$module_registry" || {
        echo 'Could not patch the generated XL module library name.' >&2
        exit 1
    }
    echo 'Set Linux XL host module path to ./libsamurai_warriors_2_SW2XL_US.so.' >&2
fi
