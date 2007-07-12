# $Id: PropertyList.pm 150 2005-06-02 12:25:41Z aschults $
package Mac::PropertyList;
use strict;

use vars qw($ERROR $XML_head $XML_foot $VERSION);

use Carp qw(croak);

$VERSION = 0.51;

=head1 NAME

Mac::PropertyList - work with Mac plists at a low level

=head1 SYNOPSIS

	use Mac::PropertyList;

	my $data  = parse_plist( $text );

	my $text  = plist_as_string( $data );

	my $plist = create_from_hash(  \%hash  );
	my $plist = create_from_array( \@array );

	my $plist = Mac::PropertyList::dict->new( \%hash );
		
	
=head1 DESCRIPTION

This module is a low-level interface to the Mac OS X
Property List (plist) format.  You probably shouldn't use this
in applications---build interfaces on top of this so
you don't have to put all the heinous multi-level object
stuff where people can see it.

You can parse a plist file and get back a data structure.
You can take that data structure and get back the plist
as XML.  If you want to change the structure inbetween
that's your business. :)

=head2 The Property List format

The MacOS X Property List format is simple XML.  You
can read the DTD to get the details.

	http://www.apple.com/DTDs/PropertyList-1.0.dtd

One big problem exists---its dict type uses a flat
structure to list keys and values so that values
are only associated with their keys by their position
in the file rather than by the structure of the DTD.
This problem is the major design hinderance in this
module.  A smart XML format would have made things
much easier.

If the parse_plist encounters an empty key tag in a dict
structure (i.e. C<< <key></key> >> ) the function croaks.

=head2 The Mac::PropertyList classes

A plist can have one or more of any of the plist
objects, and we have to remember the type of thing
so we can go back to the XML format.  Perl treats
numbers and strings the same, but the plist format
doesn't.

Therefore, everything Mac::PropertyList creates is
an object of some sort.  Container objects like
Mac::PropertyList::array and Mac::PropertyList::dict
hold other objects.

There are several types of objects: 

	Mac::PropertyList::string
	Mac::PropertyList::data
	Mac::PropertyList::real
	Mac::PropertyList::integer
	Mac::PropertyList::date
	Mac::PropertyList::array
	Mac::PropertyList::dict

=over 4
 
=item new( VALUE )

Create the object.

=item value

Access the value of the object.  At the moment you cannot
change the value

=item type

Access the type of the object (string, data, etc)

=item write

Create a string version of the object, recursively if necessary.

=back

=cut

my $Debug = $ENV{PLIST_DEBUG} || 0;

$XML_head =<<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
XML

$XML_foot =<<"XML";
</plist>
XML

my %Readers = (
	"dict"    => \&read_dict,
	"string"  => \&read_string,
	"date"    => \&read_date,
	"real"    => \&read_real,
	"integer" => \&read_integer,
	"string"  => \&read_string,
	"array"   => \&read_array,
	"data"    => \&read_data,
	"true"    => \&read_true,
	"false"   => \&read_false,
	);

my $Options = {ignore => ['<true/>', '<false/>']};

=head1 FUNCTIONS

=over 4

=item parse_plist( TEXT )

Parse the XML plist in TEXT and return the Mac::PropertyList
object.

=cut

sub parse_plist
	{
	my $text = shift;

	# we can handle either 0.9 or 1.0
	$text =~ s|^<\?xml.*?>\s*<!DOC.*>\s*<plist.*?>\s*||;
	$text =~ s|<!--.*?-->||smg;
	$text =~ s|\s*</plist>\s*$||;

	my $plist = read_next( \$text );

	return $plist;
	}

=item parse_plist_file( FILE_PATH )

Parse the XML plist in TEXT and return the Mac::PropertyList
data structure.

=cut

sub parse_plist_file
	{
	my $file = shift;

	return unless -e $file;
	
	my $text = do { local $/; open my($fh), $file; <$fh> };
	
	parse_plist( $text );
	}

=item create_from_hash( HASH_REF )

Create a plist dictionary from the hash reference.

The values of the hash can only be simple scalars---not
references.  Reference values are silently ignored.

Returns a string representing the hash in the plist format.

=cut

sub create_from_hash
	{
	my $hash  = shift;

	return unless UNIVERSAL::isa( $hash, 'HASH' );

	my $string = "$XML_head" . Mac::PropertyList::dict->write_open . "\n";

	foreach my $key ( keys %$hash )
		{
		next if ref $hash->{$key};
		
		my $bit   = Mac::PropertyList::dict->write_key( $key ) . "\n";
		my $value = Mac::PropertyList::string->new( $hash->{$key} );
		
		$bit  .= $value->write . "\n";

		$bit =~ s/^/\t/gm;

		$string .= $bit;
		}

	$string .= Mac::PropertyList::dict->write_close . "\n$XML_foot";

	return $string;
	}

=item create_from_array( ARRAY_REF )

Create a plist array from the array reference.

The values of the array can only be simple scalars---not
references.  Reference values are silently ignored.

Returns a string representing the array in the plist format.

=cut

sub create_from_array
	{
	my $array  = shift;

	return unless UNIVERSAL::isa( $array, 'ARRAY' );

	my $string = "$XML_head" . Mac::PropertyList::array->write_open . "\n";

	foreach my $element ( @$array )
		{		
		my $value = Mac::PropertyList::string->new( $element );
		
		my $bit  .= $value->write . "\n";
		$bit =~ s/^/\t/gm;

		$string .= $bit;
		}

	$string .= Mac::PropertyList::array->write_close . "\n$XML_foot";

	return $string;
	}

sub read_string  { Mac::PropertyList::string ->new( $_[0] )  }
sub read_integer { Mac::PropertyList::integer->new( $_[0] )  }
sub read_date    { Mac::PropertyList::date   ->new( $_[0] )  }
sub read_real    { Mac::PropertyList::real   ->new( $_[0] )  }
sub read_true    { Mac::PropertyList::true   ->new           }
sub read_false   { Mac::PropertyList::false  ->new           }

sub read_next
	{
	my $ref = shift;

	my $value = do {
		my $tag;
		my $value;
		if( $$ref =~ s[^\s* < (string|date|real|integer|data) >
			\s*(.*?)\s* </\1> ][]sx )
			{
			print STDERR "read_next: Found value type [$1] with value [$2]\n"
				if $Debug > 1;
			$Readers{$1}->( $2 );
			}
		elsif( $$ref =~ s[^\s* < (dict|array) > ][]x )
			{
			print STDERR "\$1 is [$1]\n" if $Debug > 1;
			$Readers{$1}->( $ref );
			}
		# these next two are some wierd cases i found in the iPhoto Prefs
		elsif( $$ref =~ s[^\s* < dict / > ][]x )
			{
			return Mac::PropertyList::dict->new();
			}
		elsif( $$ref =~ s[^\s* < array / > ][]x )
			{
			return Mac::PropertyList::array->new();
			}
		elsif( $$ref =~ s[^\s* < (true|false) /> ][]x )
			{
			print STDERR "\$1 is [$1]\n" if $Debug > 1;
			$Readers{$1}->();
			}
		};

	}

sub read_dict
	{
	my $ref = shift;
	print STDERR "Processing dict\n" if $Debug > 1;

	my %hash;

	while( not $$ref =~ s|^\s*</dict>|| )
		{
		$$ref =~ s[^\s*<key>(.*?)</key>][]s;
		print STDERR "read_dict: key is [$1]\n" if $Debug > 1;
		croak "Could not read key!" unless defined $1 and $1 ne '';
		my $key = $1;
		$hash{ $key } = read_next( $ref );
		}

	return Mac::PropertyList::dict->new( \%hash );
	}

sub read_array
	{
	my $ref = shift;
	print STDERR "Processing array\n" if $Debug > 1;

	my @array = ();

	while( not $$ref =~ s|^\s*</array>|| )
		{
		push @array, read_next( $ref );
		}

	return Mac::PropertyList::array->new( \@array );
	}

sub read_data
	{
	my $string = shift;

	require MIME::Base64;

	$string = MIME::Base64::decode_base64($string);

	return Mac::PropertyList::data->new( $string );
	}

sub plist_as_string
	{
	my $object = shift;

	my $string = $XML_head;

	$string .= $object->write . "\n";

	$string .= $XML_foot;

	return $string;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::Item;
sub type_value { ( $_[0]->type, $_[0]->value ) }

sub value      
	{ 
	my $ref = $_[0]->type;
	my $new_val = $_[1];

	if(defined $new_val)
	  {
	    ${$_[0]}=$new_val;
	  }
	else
	  {
	    do {
		   if( $ref eq 'array' ) { wantarray ? @{ $_[0] } : $_[0] }
		elsif( $ref eq 'dict'  ) { wantarray ? %{ $_[0] } : $_[0] }
		else                     { ${ $_[0] } }
	        };
	  }
	}
	
sub type { my $r = ref $_[0] ? ref $_[0] : $_[0]; $r =~ s/.*:://; $r; }

sub new { bless $_[1], $_[0] }
	
sub write_open  { $_[0]->write_either(); }
sub write_close { $_[0]->write_either('/'); }

sub write_either
	{
	my $slash = defined $_[1] ? '/' : '';
	
	my $type = $_[0]->type;
	
	"<$slash$type>";
	}
	
sub write_empty { my $type = $_[0]->type; "<$type/>"; }
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::Container;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Item');

sub new
	{
	my $class = shift;
	
	if( ref $_[0] )
		{
		return bless $_[0], $class;
		}
		
	my $empty = do {
		   if( $class =~ m/array$/ ) { [] }
		elsif( $class =~ m/dict$/  ) { {} }
		};
		
	$class->SUPER::new( $empty );
	}
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::array;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Container');

sub shift   { shift @{ $_[0]->value } }
sub unshift { }
sub pop     { pop @{ $_[0]->value }   }
sub push    { }
sub splice  { }
sub count   { return scalar @{ $_[0]->value } }

sub values { my @v = map { $_->value } @{ $_[0]->value }; wantarray ? @v : \@v }

sub value
        {
	my $self = CORE::shift;
	my $key  = CORE::shift;
	my $new_val = CORE::shift;

	if(defined $new_val)
	  {
	    $self->[$key]=$new_val;
	  }
	else
	  {
	    do
		{
		if( defined $key )
			{
			my $hash = $self->SUPER::value;
			
			if( exists $hash->{$key} ) { $hash->{$key} }
			else                       { return }
			}
		else { $self->SUPER::value }
		};
 	  }	
        }


sub write
	{
	my $self  = CORE::shift;

	my $string = $self->write_open . "\n";

	foreach my $element ( @$self )
		{
		  #only write if we have a defined element. --> Skip undefs
		  if($element)
		    {
		      my $bit = $element->write;
		      
		      $bit =~ s/^/\t/gm;
		      
		      $string .= $bit . "\n";
		    }
		}

	$string .= $self->write_close;

	return $string;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::dict;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Container');

sub delete { delete ${ $_[0]->value }{$_[1]}         }
sub exists { exists ${ $_[0]->value }{$_[1]} ? 1 : 0 }
sub count  { scalar CORE::keys %{ $_[0]->value }     }

sub value
	{
	my $self = shift;
	my $key  = shift;
	my $new_val = shift;

	if(defined $new_val)
	  {
	    $self->{$key}=$new_val;
	  }
	else
	  {
	    do
		{
		if( defined $key )
			{
			my $hash = $self->SUPER::value;
			
			if( exists $hash->{$key} ) { $hash->{$key} }
			else                       { return }
			}
		else { $self->SUPER::value }
		};
	  }	
	}
	
sub keys   { my @k = CORE::keys %{ $_[0]->value }; wantarray ? @k : \@k; }
sub values { my @v = map { $_->value } CORE::values %{ $_[0]->value }; wantarray ? @v : \@v; }

sub write_key   { "<key>$_[1]</key>" }

sub write
	{
	my $self  = shift;

	my $string = $self->write_open . "\n";

	foreach my $key ( $self->keys )
		{
		my $element = $self->{$key};

		my $bit  = __PACKAGE__->write_key( $key ) . "\n";
		   $bit .= $element->write . "\n";

		$bit =~ s/^/\t/gm;

		$string .= $bit;
		}

	$string .= $self->write_close;

	return $string;
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::Scalar;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Item');

sub new { my $copy = $_[1]; $_[0]->SUPER::new( \$copy ) }

sub write { $_[0]->write_open . $_[0]->value . $_[0]->write_close }
	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::date;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Scalar');

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::real;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Scalar');

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::integer;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Scalar');

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::string;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Scalar');

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::data;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Scalar');

sub write
	{
	my $self  = shift;

	my $type  = $self->type;
	my $value = $self->value;

	require MIME::Base64;

	my $string = MIME::Base64::encode_base64($value);

	$self->write_open . $string . $self->write_close; 
	}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::Boolean;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Item');

sub new
	{
	my $class = shift;
	
	my( $type ) = $class =~ m/.*::(.*)/g;
		
	$class->either( $type );
	}
	
sub either { my $copy = $_[1]; bless \$copy, $_[0]  }

sub write  { $_[0]->write_empty }

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::true;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Boolean');

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
package Mac::PropertyList::false;
use vars qw/@ISA/; @ISA = ('Mac::PropertyList::Boolean');

=back

=head1 SOURCE AVAILABILITY

This source is part of a SourceForge project which always has the
latest sources in CVS, as well as all of the previous releases.

	https://sourceforge.net/projects/brian-d-foy/

If, for some reason, I disappear from the world, one of the other
members of the project can shepherd this module appropriately.

=head1 CREDITS

Thanks to Chris Nandor for general Mac kung fu and Chad Walker
for help figuring out the recursion for nested structures.

=head1 TO DO

* change the value of an object

* validate the values of objects (date, integer)

* methods to add to containers (dict, array)

* do this from a filehandle or a scalar reference instead of a scalar
	+ generate closures to handle the work.

=head1 AUTHOR

brian d foy, E<lt>bdfoy@cpan.orgE<gt>

=head1 SEE ALSO

http://www.apple.com/DTDs/PropertyList-1.0.dtd

=cut

"See why 1984 won't be like 1984";
