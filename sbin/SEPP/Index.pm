package SEPP::Index;

# read and write index.txt files as used by 'seppadm expose' and 'sepp-get'
# it is also used to write /usr/sepp/html/.pdbcache

sub index_read($)
{
    my ($file) = @_;
    my %index;
    local $_;

    open(INDEX, $file) or do {
        warn "WARNING: can't open $file";
        return {};
    };

    while(<INDEX>) {
        chomp;
        my $pack = $_;
        data: while(<INDEX>) {
            chomp;
            if(/^\s*$/) { last data; }
            if(/(.*?):[ \t]+(.*)/) {
                $index{$pack}{$1}=$2;
            }
        }
    }

    return \%index;
}

sub index_write($$)
{
    my ($index, $file) = @_;
    open(INDEX, ">$file") or die "ERROR: can't write $file";
    my $pack;
    foreach $pack (keys %$index) {
        print INDEX "$pack\n";
        for my $a (sort keys %{$index->{$pack}}) {
            printf INDEX "%-15s %s\n", "$a:", $index->{$pack}{$a};
        }
        print INDEX "\n";
    }
}

1;
