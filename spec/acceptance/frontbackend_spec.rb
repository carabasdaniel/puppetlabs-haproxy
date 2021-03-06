require 'spec_helper_acceptance'

describe 'frontend backend defines' do
  pp_one = <<-PUPPETCODE
      class { 'haproxy': }
      haproxy::frontend { 'app00':
        ipaddress => $::ipaddress_lo,
        mode      => 'http',
        ports     => '5555',
        options   => { 'default_backend' => 'app00' },
      }
      haproxy::backend { 'app00':
        collect_exported => false,
        options          => { 'mode' => 'http' },
      }
      haproxy::balancermember { 'port 5556':
        listening_service => 'app00',
        ports             => '5556',
      }
      haproxy::balancermember { 'port 5557':
        listening_service => 'app00',
        ports             => '5557',
      }
  PUPPETCODE
  it 'is able to configure the frontend/backend with puppet' do
    retry_on_error_matching do
      apply_manifest(pp_one, catch_failures: true)
    end
  end

  # This is not great since it depends on the ordering served by the load
  # balancer. Something with retries would be better.
  # C9945
  it 'does a curl against the LB to make sure it gets a response from each port' do
    response_connection = shell('curl localhost:5555').stdout.chomp
    response_connection.should match(%r{Response on 555(6|7)})
    if response_connection == 'Response on 5556'
      shell('curl localhost:5555').stdout.chomp.should match(%r{Response on 5557})
    else
      shell('curl localhost:5555').stdout.chomp.should match(%r{Response on 5556})
    end
  end

  pp_two = <<-PUPPETCODE
      class { 'haproxy': }
      haproxy::frontend { 'app00':
        ipaddress => $::ipaddress_lo,
        mode      => 'http',
        ports     => '5555',
        options   => { 'default_backend' => 'app00' },
      }
      haproxy::backend { 'app00':
        collect_exported => false,
        options          => { 'mode' => 'http' },
      }
      haproxy::balancermember { 'port 5556':
        listening_service => 'app00',
        ports             => '5556',
      }
      haproxy::balancermember { 'port 5557':
        listening_service => 'app00',
        ports             => '5558',
      }
  PUPPETCODE
  it 'is able to configure the frontend/backend with one node up' do
    retry_on_error_matching do
      apply_manifest(pp_two, catch_failures: true)
    end
  end

  # C9951
  it 'does a curl against the LB to make sure it gets a response from each port #onenodeup' do
    shell('curl localhost:5555').stdout.chomp.should match(%r{Response on 5556})
    shell('curl localhost:5555').stdout.chomp.should match(%r{Response on 5556})
  end

  pp_three = <<-PUPPETCODE
      class { 'haproxy': }
        haproxy::frontend { 'app0':
        bind =>
          { '127.0.0.1:5555' => [] }
          ,
        }
  PUPPETCODE
  it 'having no address set but setting bind' do
    retry_on_error_matching do
      apply_manifest(pp_three, catch_failures: true)
    end
  end
end
