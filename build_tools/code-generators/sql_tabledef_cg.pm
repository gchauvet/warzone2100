#!/usr/bin/perl -w
# vim: set et sts=4 sw=4:

package CG;
use strict;

# Code generator for SQL table definitions

sub printStructFieldType
{
    my ($output, $field) = @_;

    $_ = ${$field}{"type"};

    if    (/count/)     { $$output .= "INTEGER NOT NULL"; }
    elsif (/string/)    { $$output .= "TEXT NOT NULL"; }
    elsif (/real/)      { $$output .= "NUMERIC NOT NULL"; }
    elsif (/bool/)      { $$output .= "INTEGER NOT NULL"; }
    elsif (/enum/)      { $$output .= "INTEGER NOT NULL"; }
    elsif (/IMD_model/) { $$output .= "TEXT NOT NULL"; }
    else                { die "UKNOWN TYPE: $_"; }
}

sub printComments
{
    my ($output, $comments, $indent) = @_;

    return unless @{$comments};

    foreach my $comment (@{$comments})
    {
        $$output .= "\t" if $indent;
        $$output .= "--${comment}\n";
    }
}

sub printStructFields
{
    my ($output, $struct, $enumMap) = @_;
    my @fields = @{${$struct}{"fields"}};
    my @constraints = ();

    while (@fields)
    {
        my $field = shift(@fields);

        printComments($output, ${$field}{"comment"}, 1);

        if (${$field}{"type"} and ${$field}{"type"} =~ /set/)
        {
            my $enumName = ${$field}{"enum"};
            my $enum = ${$enumMap}{$enumName};
            my @values = @{${$enum}{"values"}};
            my $unique_string = "UNIQUE(";

            while (@values)
            {
                my $value = shift(@values);

                $$output .= "\t${$field}{\"name\"}_${$value}{\"name\"} INTEGER NOT NULL";
                $$output .= "," if @values or @fields or @constraints or grep(/unique/, @{${$field}{"qualifiers"}});
                $$output .= "\n";
                $unique_string .= "${$field}{\"name\"}_${$value}{\"name\"}";
                $unique_string .= ", " if @values;
            }

            $unique_string .= ")";
            push @constraints, $unique_string if grep(/unique/, @{${$field}{"qualifiers"}});
        }
        else
        {
            $$output .= "\t${$field}{\"name\"} ";
            printStructFieldType($output, $field);
            $$output .= " UNIQUE" if grep(/unique/, @{${$field}{"qualifiers"}});
            $$output .= ",\n" if @fields or @constraints;
        }

        $$output .= "\n";
    }

    while (@constraints)
    {
        my $constraint = shift(@constraints);

        $$output .= "\t${constraint}";
        $$output .= ",\n" if @constraints;
        $$output .= "\n";

    }
}

sub printStructContent
{
    my ($output, $struct, $name, $structMap, $enumMap, $printFields) = @_;

    foreach (keys %{${$struct}{"qualifiers"}})
    {
        if (/inherit/)
        {
            my $inheritName = ${${$struct}{"qualifiers"}}{"inherit"};
            my $inheritStruct = ${$structMap}{$inheritName};

            printStructContent($output, $inheritStruct, $name, $structMap, $enumMap, 0);
        }
        elsif (/abstract/)
        {
            $$output .= "\t-- Automatically generated ID to link the inheritance hierarchy.\n"
                     .  "\tunique_inheritance_id INTEGER PRIMARY KEY ";
            $$output .= "AUTOINCREMENT " if $printFields;
            $$output .= "NOT NULL,\n\n";
        }
    }

    $$name = ${$struct}{"name"};

    printStructFields($output, $struct, $enumMap) if $printFields;
}

sub printEnum()
{
}

sub printStruct()
{
    my ($output, $struct, $structMap, $enumMap) = @_;
    my $name = ${$struct}{"name"};

    printComments($output, ${$struct}{"comment"}, 0);

    # Start printing the structure
    $$output .= "CREATE TABLE `${name}` (\n";

    printStructContent($output, $struct, \$name, $structMap, $enumMap, 1);

    # Finish printing the structure
    $$output .= ");\n\n";
}

sub startFile()
{
    my ($output, $name) = @_;

    $$output .= "-- This file is generated automatically, do not edit, change the source ($name) instead.\n\n";
}

sub endFile()
{
}

1;
