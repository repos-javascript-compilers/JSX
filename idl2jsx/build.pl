#!/usr/bin/env perl
use 5.10.0;
use strict;
use warnings;
use Text::Xslate;
use File::Path qw(mkpath);
use Data::Section::Simple;
use Fatal qw(open close);
use File::Basename qw(dirname);
use Storable qw(lock_retrieve);
use Tie::IxHash;

my $lib = "lib/js/js";
mkpath $lib;

# the order is important!

my $root = dirname(__FILE__);
unlink "$root/.idl2jsx.bin";

my @specs = (
    ['web.jsx' =>
        # DOM spec
        #'http://www.w3.org/TR/DOM-Level-3-Core/idl/dom.idl',
        'http://www.w3.org/TR/dom/',
        'http://www.w3.org/TR/DOM-Level-2-Views/idl/views.idl',
        'http://www.w3.org/TR/DOM-Level-3-Events/',
        "$root/extra/events.idl",
        'http://www.w3.org/TR/html5/single-page.html',

        'http://www.w3.org/TR/XMLHttpRequest/',

        'http://www.w3.org/TR/selectors-api/',

        # there're syntax errors in the IDL!
        #'http://html5labs.interoperabilitybridges.com/dom4events/',

        'http://dev.w3.org/csswg/cssom/',
        'http://dev.w3.org/csswg/cssom-view/',
        "$root/extra/chrome.idl",
        "$root/extra/firefox.idl",

        # HTML5
        'http://www.w3.org/TR/FileAPI/',
        "$root/extra/file.idl",

        "http://html5.org/specs/dom-parsing.html",

        # graphics
        'https://www.khronos.org/registry/typedarray/specs/latest/typedarray.idl',
        'http://dev.w3.org/html5/2dcontext/',
        'https://www.khronos.org/registry/webgl/specs/latest/webgl.idl',
    ],
);

my $HEADER = <<'T';
// THIS FILE IS AUTOMATICALLY GENERATED.
T

my $xslate = Text::Xslate->new(
    path  => [ Data::Section::Simple->new->get_data_section() ],
    type => "text",

    function => {
    },
);

foreach my $spec(@specs) {
    my($file, @idls) = @{$spec};
    say "generate $file from ", join ",", @idls;

    my %param = (
        idl => scalar(`idl2jsx/idl2jsx.pl --continuous @idls`),
    );
    if($? != 0) {
        die "Cannot convert @idls to JSX.\n";
    }

    $param{classdef} = lock_retrieve("$root/.idl2jsx.bin");
    $param{html_elements} = [
        map  {
            ($_->{func_name} = $_->{name}) =~ s/^HTML//;
            ($_->{tag_name} = lc $_->{func_name}) =~ s/element$//;
            $_; }
        grep { $_->{base} ~~ "HTMLElement"  } values %{ $param{classdef} },
    ];

    my $src = $xslate->render($file, \%param);

    open my($fh), ">", "$lib/$file";
    print $fh $HEADER;
    print $fh $src;
    close $fh;
}

__DATA__
@@ web.jsx
/**

Web Browser Interface

*/
import "js.jsx";

final class web {
	static const window = js.global["window"] as __noconvert__ Window;

	static function id(id : string) : HTMLElement {
		return web.window.document.getElementById(id) as HTMLElement;
	}

	// type-safe API for createElement() and getElementById()

: for $html_elements -> $class {
	static function create<: $class.func_name :>() : <: $class.name :> {
		return web.window.document.createElement("<: $class.tag_name :>")
			as __noconvert__ <: $class.name :>;
	}
	static function get<: $class.func_name :>ById(id : string) : <: $class.name :> {
		return web.window.document.getElementById(id)
			as <: $class.name :>;
	}
: }

}

: $idl

