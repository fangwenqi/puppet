require 'rexml/document'

test_name "should modify a scheduled task"

name = "pl#{rand(999999).to_i}"
confine :to, :platform => 'windows'

verylongstring = 'a' * 1024

agents.each do |agent|
  # Have to use /v1 parameter for Vista and later, older versions
  # don't accept the parameter
  version = '/v1'
  on agents, facter('kernelmajversion') do
    version = '' if stdout.chomp.to_f < 6.0
  end

  step "create the task"
  on agent, "schtasks.exe /create #{version} /tn #{name} /tr c:\\\\windows\\\\system32\\\\notepad.exe /sc daily /ru system"

  step "modify the task"
  # use long arg string, but be careful not to exceed Windows maximum command line length of 8191 on XP+
  on agent, puppet_resource('scheduled_task', name, ['ensure=present', 'command=c:\\\\windows\\\\system32\\\\notepad2.exe', "arguments=args-#{verylongstring}"])

  # note that this only verifies the output of the ITaskScheduler / ITask COM API
  # and unfortunately schtasks.exe and the MMC snap-in may get out of sync
  step "verify the arguments were updated from Puppet"
  on agent, puppet_resource('scheduled_task', name) do
    assert_match(/command\s*=>\s*'c:\\windows\\system32\\notepad2.exe'/, stdout)
    assert_match(/arguments\s*=>\s*'args-#{verylongstring}'/, stdout)
  end

  step "verify that schtasks reports the same output"
  on agent, "schtasks.exe /query /tn #{name} /xml" do
    xml = REXML::Document.new(stdout)

    command =  xml.root.elements['//Actions/Exec/Command/text()'].value
    arguments = xml.root.elements['//Actions/Exec/Arguments/text()'].value

    assert_match('c:\\windows\\system32\\notepad2.exe', command)
    assert_match("args-#{verylongstring}", arguments)
  end

  step "delete the task"
  on agent, "schtasks.exe /delete /tn #{name} /f"
end
