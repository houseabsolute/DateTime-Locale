requires "Carp" => "0";
requires "Dist::CheckConflicts" => "0.02";
requires "Exporter" => "0";
requires "List::MoreUtils" => "0";
requires "Params::Validate" => "0";
requires "perl" => "5.008001";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "Storable" => "0";
  requires "Test::Fatal" => "0";
  requires "Test::More" => "0.96";
  requires "Test::Requires" => "0";
  requires "Test::Warnings" => "0";
  requires "base" => "0";
  requires "utf8" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Dist::CheckConflicts" => "0.02";
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Code::TidyAll" => "0.24";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Perl::Critic" => "1.123";
  requires "Perl::Tidy" => "20140711";
  requires "Test::CPAN::Changes" => "0.19";
  requires "Test::Code::TidyAll" => "0.24";
  requires "Test::EOL" => "0";
  requires "Test::More" => "0.88";
  requires "Test::NoTabs" => "0";
  requires "Test::Output" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};
