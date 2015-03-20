package Sympa::Client::Scrappy; 
use Modern::Perl;
use Scrappy;
use Scrappy::Scraper::Parser;
use Moo;
use Carp;

#ABSTRACT:  Scrapper to Sympa 6.x administration console

=head1 SYNOPSIS

Sympa::Client::Scrappy is a Scrapper on 6.x to automate some adminsitration tasks. i wrote it to manage requests directly from mutt/vim.

    my $s = Sympa::Client::Scrappy->new
    ( base => 'http://base.example.com/sympa'
    , bot  => 'example.com' );

    say $s->url_for
    # http://base.example.com/sympa/example.com/

    say $s->url_for('get_pending_lists')
    # http://base.example.com/sympa/example.com/get_pending_lists/

    $s->login( admin => 'seCr3t' );
    $s->rename_list( leaders => 'oldmen' );

    map { say "$_->{requestor} want a list named $_->{name}" }
    , @{ $s->get_pending_lists };

=head1 SOURCES REPOSITORY

    github.com/unistra/p5-sympa-client-scrappy

=head1 ATTRIBUTES

    base   (rw,required)    the base url to contact the sympa webapp
    bot    (rw,required)    the robot you want to administrate
    ua     (rw,default)     direct access to scrappy

=head1 METHODS

=head2 ok

last http request was a success

=head2 url_for

write an url relative to the robot.

=head2 get
=head2 close_list
=head2 restore_list
=head2 post
=head2 rename_list
=head2 login
=head2 get_pending_lists

=cut

has $_ => qw< is rw required 1 >
    for qw< base bot >;

has qw< ua is rw >
, default => sub { Scrappy->new };

sub BUILDARGS {
    shift;
    my %arg = @_;
    if ( $arg{url} ) { ... } # should set base and bot ? 
    \%arg
}


sub _uok { (shift)->response->is_success     }
sub ok   { (shift)->ua->response->is_success }

sub url_for {
    my $self = shift;
    join '/'
    , $self->base
    , $self->bot
    , @_
}

sub get {
    my $self = shift;
    my $ua = $self->ua;
    my $url = $self->url_for(@_);
    $ua->get( $url );
    $ua->page_loaded;
}

sub close_list {
    my ( $self, $list ) = @_;
    $self->get( close_list => $list );
}

sub restore_list {
    my ( $self, $list ) = @_;
    $self->get( restore_list => $list );
}


sub post {
    my $self = shift;
    my $form = pop or confess;
    my $ua  = $self->ua;
    my $url = $self->url_for( @_ );
    $ua->post( $url, $form );
    $ua->page_loaded;
}

sub rename_list {
    my ( $self, $old, $new, $bot ) =  @_;
    $bot ||= $self->bot;
    my $url = $self->url_for;
    say "renaming $url ($bot) $old => $new";
    $self->post
    ( $self->url_for
    ,   { action_rename_list => 1
        , list         => $old
        , new_listname => $new
        , new_robot    => $bot } );
}

sub install_pending_list {
    my $self = shift;
    my $request = {qw<
        action_install_pending_list do 
        notify yes
        status open
        list >
        , @_ };

    $self->post($request);

}

sub login {
    my ( $self, $login, $passwd ) = @_;
    die unless $self->post
        (   { action => 'login'
            , email  => $login
            , passwd => $passwd } );
    grep /Admin Sympa/, $self->ua->page_data; # check if login success
}

sub _extract_pending_list_request (_) {
    state $parser = Scrappy::Scraper::Parser->new;
    my $html = (shift)->{html};
    return () unless $html =~ /set_pending_list_request/;
    my %data;
    @data{qw< name desc requestor date  >} =
        map { $_->{text} } @{ $parser->select('td', $html)->data };
    \%data;
}

sub get_pending_lists {
    my $self = shift;
    confess YAML::Dump $self->ua unless $self->get('get_pending_lists');
    map _extract_pending_list_request
    , @{  $self->ua->select('tr')->data }
}

1;
