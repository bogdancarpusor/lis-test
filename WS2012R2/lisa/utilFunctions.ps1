#####################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
#####################################################################

<#
.Synopsis
    Helper functions for the Lisa automation.

.Description
    The functions in this file are helper functions for the
    the lisa.ps1 and stateEngine.ps1 automation scripts.

.Link
    None.
#>

#####################################################################
#
# GetJUnitXML
#
#####################################################################
function GetJUnitXML()
{
    <#
    .Synopsis
        Generate a JUnit XML object from template file.

    .Description
        Load JUnit XML result template file, and generate an XML object.

    .ReturnValue
        An xml object of JUnit result.
        Output type: [XML]
    .Example
        GetJUnitXML
    #>
    LogMsg 6 ("Info :    GetJUnitXML()")
    $template = @'
<testsuite name="" timestamp="">
<properties>
    <property name="hyperv.version" value="" />
    <property name="kernel.version" value="" />
    <property name="firmware.version" value="" />
</properties>
<testcase name="" time="">
    <skipped/>
    <failure type=""></failure>
    <properties>
        <property name="tc_covered" value="" />
    </properties>
</testcase>
</testsuite>
'@

    $guid = [System.Guid]::NewGuid().ToString("N")
    $templatePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $guid + ".txt");
    $template | Out-File $templatePath -encoding UTF8
    # load template into XML object
    $junit_xml = New-Object xml
    $junit_xml.Load($templatePath)
    Remove-Item $templatePath
    return $junit_xml
}

#####################################################################
#
# SetHypervVersion
#
#####################################################################
function SetHypervVersion([String] $ver)
{
    <#
    .Synopsis
        Add Hyperv version into XML result.

    .Description
        Find the Hyperv version property and set Hyperv version into result XML object.

    .Parameter ver
        The version of Hyperv host.
        Type : [String]

    .Example
        SetHypervVersion ""
    #>
    LogMsg 6 ("Info :    SetHypervVersion($($ver))")

    foreach ($property in $testResult.testsuite.properties.property)
    {
        if ($property.name -eq "hyperv.version")
        {
            $property.value = $ver
            return
        }
    }
}

#####################################################################
#
# SetOSInfo
#
#####################################################################
function SetOSInfo([String] $kernelVer, [String] $firmwareVer)
{
    <#
    .Synopsis
        Add Kernel and firmware version into XML result.

    .Description
        Find the Kernel and firmware version properties and set Kernel
        and firmware version into result XML object.

    .Parameter kernelVer
        The version of guest kernel.
        Type : [String]

    .Parameter firmwareVer
        The version of guest firmware info.
        Type : [String]

    .Example
        SetOSInfo "2.6.32-694.el6.x86_64" "BIOS"
    #>
    LogMsg 6 ("Info :    SetOSInfo($($kernelVer), $($firmwareVer))")

    foreach ($property in $testResult.testsuite.properties.property)
    {
        if ($property.name -eq "kernel.version" -and $property.value -eq "")
        {
            $property.value = $kernelVer
        }

        if ($property.name -eq "firmware.version" -and $property.value -eq "")
        {
            $property.value = $firmwareVer
        }
    }
}

#####################################################################
#
# SetResultSuite
#
#####################################################################
function SetResultSuite([String] $testSuite)
{
    <#
    .Synopsis
        Configure test suite in result XML object.

    .Description
        Find the test suite, and configure test suite into result XML object.

    .Parameter testSuite
        The name of the test suite to run
        Type : [String]

    .Example
        SetResultSuite "acceptance"
    #>
    LogMsg 6 ("Info :    SetResultSuite($($testSuite))")

    $testResult.testsuite.name = $testSuite
}

#####################################################################
#
# SetTimeStamp
#
#####################################################################
function SetTimeStamp([String] $testTimeStamp)
{
    <#
    .Synopsis
        Add test date time in result XML object.

    .Description
        Find the test suite, and configure test date time into result XML object.

    .Parameter testTimeStamp
        The start time of test run
        Type : [String]

    .Example
        SetTimeStamp "02/21/2017 13:14:25"
    #>
    LogMsg 6 ("Info :    SetTimeStamp($($testTimeStamp))")

    $testResult.testsuite.timestamp = $testTimeStamp
}

#####################################################################
#
# SetTestResult
#
#####################################################################
function SetTestResult([String] $testName, [String] $completionCode, [xml] $xmlData )
{
    <#
    .Synopsis
        Add test case result into result XML object except running time.

    .Description
        Clone a test case group as template, add test result into that group.

    .Parameter testName
        The name of the test
        Type : [String]

    .Parameter completionCode
        The test result, such as Passed, Failed, Skipped, and Aborted
        Type : [String]

    .Parameter xmlData
            XML configuration settings.
            Type : [xml]

    .Example
        SetTestResult $testName $completionCode
    #>
    LogMsg 6 ("Info :    SetTestResult($($testName))")

    $newTestCaseTemplate = (@($testResult.testsuite.testcase)[0]).Clone()
    $newTestCase = $newTestCaseTemplate.clone()
    $newTestCase.name = $testName
    switch ($completionCode)
    {
        "Passed" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
        }
        "Skipped" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[1]) | Out-Null
        }
        "Failed" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.failure.type = "Failed"
            $newTestCase.failure.InnerText = "Test $testName Failed."
        }
        "Aborted" {
            $newTestCase.RemoveChild($newTestCase.ChildNodes[0]) | Out-Null
            $newTestCase.failure.type = "Aborted"
            $newTestCase.failure.InnerText = "Test $testName Aborted."
        }
    }

    $testID = GetTestID $testName $xmlData

    foreach ($property in $newTestCase.properties.property)
    {
        if ($property.name -eq "TC_COVERED")
        {
            $property.value = $testID
            break
        }
    }
    $testResult.testsuite.AppendChild($newTestCase) > $null
}

#####################################################################
#
# SetRunningTime
#
#####################################################################
function SetRunningTime([String] $testName, [System.Xml.XmlElement] $vm)
{
    <#
    .Synopsis
        Set running time in result XML object.

    .Description
        Find the test case, and configure test running time into result XML object.

    .Parameter testName
        The test name
        Type : [String]

   .Parameter vm
        An XML element representing the VM
        Type : [System.Xml.XmlElement]

    .Example
        SetRunningTime $testName $vm
    #>
    LogMsg 6 ("Info :    SetRunningTime($testName)")
    $caseEndTime = [DateTime]::Now
    $deltaTime = $caseEndTime - [DateTime]::Parse($vm.caseStartTime)
    LogMsg 0 "Info : $($vm.vmName) currentTest lasts $($deltaTime.hours) Hours, $($deltaTime.minutes) Minutes, $($deltaTime.seconds) seconds."

    $runningTime = "{0:N2}" -f $deltaTime.TotalMinutes
    foreach ($testCase in $testResult.testsuite.testcase)
    {
        if ($testCase.name -eq $testName)
        {
            $testCase.time = $runningTime
        }
    }
}

#####################################################################
#
# SaveResultToXML
#
#####################################################################
function SaveResultToXML([String] $testDir)
{
    <#
    .Synopsis
        Save test result to XML file in result folder..

    .Description
        Export result XML object into an XML file.

    .Parameter testDir
        The folder storing test log.
        Type : [String]

    .Example
        SaveResultToXML $testDir
    #>
    LogMsg 6 ("Info :    SaveResultToXML to ($($testDir))")

    $resultXMLFileName = "Report-" + $testResult.testsuite.name + ".xml"

    # remove users with undefined name (remove template)
    $testResult.testsuite.testcase | Where-Object { $_.Name -eq "" } | ForEach-Object  { [void]$testResult.testsuite.RemoveChild($_) }
    # save xml to file

    # Check to see if the provided log path is absolute
    #
    if ([System.IO.Path]::IsPathRooted($testDir))
    {
        $logPath = $testDir
    }
    else
    {
        $logPath = (Get-Item -Path ".\" -Verbose).FullName + "\" + $testDir
    }

    $resultXMLFile = $logPath + "\" + $resultXMLFileName
    $testResult.Save($resultXMLFile)
}


#####################################################################
#
# HasItBeenTooLong
#
#####################################################################
function HasItBeenTooLong([String] $timestamp, [Int] $timeout)
{
    <#
    .Synopsis
        Check to see if a timeout has occured.

    .Description
        Convert the timestamp from a string to a [DateTime] type,
        add in the timeout value and see if it is less than the
        current date/time.

    .Parameter timestamp
        A string representing the timestamp
        Type : [String]

    .Parameter timeout
        An integer timeout period in seconds.
        Type : [Int]

    .ReturnValue
        Return $True if current time is greater than timestamp + timeout,
               $false otherwise.
        Output type : [Boolean]

    .Example
        HasItBeenTooLong $myTimeStamp $myTimeOut
    #>

    $retVal = $false

    if (-not $timeStamp)
    {
        # Bad data - force a timeout
        return $True
    }

    if (-not $timeout)
    {
        # Bad data - force a timeout
        return $True
    }

    if ($timeout -le 0)
    {
        # Bad data - force a timeout
        return $True
    }

    $now = [DateTime]::Now
    $ts = [DateTime]::Parse($timestamp)
    $tooLong = [DateTime]::Compare($ts.AddSeconds($timeout), $now)

    if ($tooLong -eq -1)
    {
        LogMsg 9 "INFO : The current task is started at $timestamp"
        LogMsg 9 "INFO : Timeout is set to $timeout seconds"
        $retVal = $true
    }

    return $retVal
}

#####################################################################
#
# GetNextTest
#
#####################################################################
function GetNextTest([System.Xml.XmlElement] $vm, [xml] $xmlData)
{
    <#
    .Synopsis
        Get the name of the next test the VM is to run

    .Description
        Examine the $vm.suite field and then walk through the test suite
        to return the string name of the next test the VM is to perform.
        If all tests have been performed, return the string "done".

    .Parameter vm
        An XML element representing the VM
        Type : [System.Xml.XmlElement]

    .ReturnValue
        A string of the name of the next test.
        Output type : [Boolean]

    .Example
        GetNextTest $myVM
    #>
    LogMsg 9 "Info :    GetNextText($($vm.vmName))"
    LogMsg 9 "Debug:      vm.currentTest = $($vm.currentTest)"
    LogMsg 9 "Debug:      vm.suite = $($vm.suite)"

    $done = "done"      # Assume no more tests to run

    if (-not $vm)
    {
        LogMsg 0 "Error: GetNextTest() received a null VM parameter"
        return $done
    }

    if (-not $xmlData)
    {
        LogMsg 0 "Error: GetNextTest() received a null xmlData parameter"
        return $done
    }

    if ($vm.currentTest -eq $done)
    {
        return $done
    }

    if (-not $xmlData.config.testSuites.suite)
    {
        LogMsg 0 "Error: no test suites defined in .xml file"
        return $done
    }

    $tests = $null
    $nextTest = $done

    foreach ($suite in $xmlData.config.testSuites.suite)
    {
        if ($suite.suiteName -eq $vm.suite)
        {
            if ($suite.suiteTests)
            {
                $tests = $suite.suiteTests
            }
            else
            {
                LogMsg 0 "Error: Test suite $($ts.name) does not have any tests"
                return $done
            }
            break
        }
    }

    #
    # We found the tests for the VMs test suite. Next find the next test
    # to run.  If we are iterating the current test, and there are more
    # iterations to run, just return the current test.
    #
    if ($tests)
    {
        $prev = "unknown"
        $currentTest = $vm.currentTest
        foreach ($t in $tests.suiteTest)
        {
            if ($currentTest -eq "none")
            {
                $nextTest = [string] $t
                break
            }

            if ($currentTest -eq $prev)
            {
                $nextTest = [string] $t
                break
            }
            $prev = $t
        }
    }

    if ($vm.iteration -ne "-1")
    {
        if ($vm.currentTest -eq "none" -or $vm.currentTest -eq "done")
        {
            LogMsg 0 "Error: $($vm.vmName) has a non zero iteration count for test $($vm.currentTest)"
            return $done
        }

        $testData = GetTestData $vm.currentTest $xmlData
        if ($testData)
        {
            if ($testData.maxIterations)
            {
                $iterationNumber = [int] $vm.iteration
                $maxIterations = [int] $testData.maxIterations
                if ($iterationNumber -lt $maxIterations)
                {
                    #
                    # There are more iterations, so return current test
                    #
                    $nextTest = [string] $vm.currentTest
                }
            }
            else
            {
                LogMsg 0 "Error: $($vm.vmName) has a none zero iteration count, but test $($vm.currentTest) does not have maxIterations"
                return $done
            }
        }
        else
        {
            LogMsg 0 "Error: $($vm.vmName) cannot find test data for test $($vm.currentTest)"
            return $done
        }
    }

    return $nextTest
}

#####################################################################
#
# GetTestData
#
#####################################################################
function GetTestData([String] $testName, [xml] $xmlData)
{
    <#
    .Synopsis
        Retrieve the xml object for the specified test

    .Description
        Find the test named $testName, and return the xml element
        for that test, on $null if the test is not found.

    .Parameter testName
        The name of the test to return
        Type : [String]

    .ReturnValue
        An xml element of the specific test
        Output type: [System.Xml.XmlElement]
    .Example
        GetTestData "MyTest"
    #>
    LogMsg 6 ("Info :    GetTestData($($testName))")

    $testData = $null

    foreach ($test in $xmlData.config.testCases.test)
    {
        if ($test.testName -eq $testName)
        {
            $testData = $test
            break
        }
    }

    return $testData
}

#####################################################################
#
# GetTestID
#
#####################################################################
function GetTestID([String] $testName, [xml] $xmlData)
{
    <#
    .Synopsis
        Retrieve the xml object for the TC_COVERED of specified test

    .Description
        Find the test named $testName, and return the TC_COVERED field value,
        on $null if the test is not found.

    .Parameter testName
        The name of the test to return
        Type : [String]

    .Parameter xmlData
        XML configuration settings.
        Type : [xml]

    .ReturnValue
        An ID string with TC_COVERED Value.
        Type: [String]

    .Example
        GetTestID "MyTest" $xmlData
    #>
    LogMsg 6 ("Info :    GetTestID($($testName))")

    $idString = ""

    foreach ($test in $xmlData.config.testCases.test)
    {
        if ($test.testName -eq $testName)
        {
            foreach ($param in $test.testParams.param)
            {
                if ($param.contains("TC_COVERED="))
                {
                    $idString = $param.split("=")[1]
                    break
                }
            }
            break
        }
    }

    return $idString
}

#####################################################################
#
# GetTestTimeout
#
#####################################################################
function GetTestTimeout([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Retrieve timeout value for the VM's current test

    .Description
        Return the timeout value defined in the .xml file for
        the current test, or $null if no timeout is specified.

    .Parameter vm
        The xml element of the virtual machine
        Type : [System.Xml.XmlElement]

    .ReturnValue
        A string representing the timeout value in seconds,
        or $null if not timeout is found.
        Output type: [String]
    .Example
        GetTestTimeout $myVM
    #>

    $timeout = $null
    $testData = GetTestData $vm.currentTest $xmlData

    if ($testData.timeout)
    {
        $timeout = [string] $testData.timeout
    }

    return $timeout
}

#####################################################################
#
# AbortCurrentTest
#
#####################################################################
function AbortCurrentTest([System.Xml.XmlElement] $vm, [string] $msg)
{
    <#
    .Synopsis
        Mark the current test as aborted.

    .Description
        Displayed msg if provided, set the VM's testCaseResults to
        "False", and set the VM's state to completed, update the
        VM's timestamp

    .Parameter vm
        The xml element of the virtual machine
        Type : [System.Xml.XmlElement]

    .Parameter msg
        A string to be included in the ICA log.
        Type : [String]

    .ReturnValue
        none

    .Example
        AbortCurrentTest $myVM "This is just a test"
    #>

    #$TestAborted = "TestAborted"

    if ($null -ne $msg)
    {
        logMsg 0 "Error: $($vm.vmName) $msg"
    }

    $vm.testCaseResults = $Aborted
    $vm.state = $CollectLogFiles

    logMsg 2 "Info : $($vm.vmName) transitioned to state $($vm.state)"
    $vm.stateTimestamp = [DateTime]::Now.ToString()
}

#####################################################################
#
# SummaryToString
#
#####################################################################
function SummaryToString([XML] $xmlConfig, [DateTime] $startTime, [string] $xmlFilename, [string] $logDir)
{
    <#
    .Synopsis
        Append the summary text from each VM into a single string.

    .Description
        Append the summary text from each VM one long string. The
        string includes line breaks so it can be display on a
        console or included in an e-mail message.

    .Parameter xmlConfig
        The parsed xml from the $xmlFilename file.
        Type : [System.Xml]

    .Parameter startTime
        The date/time the ICA test run was started
        Type : [DateTime]

    .Parameter xmlFilename
        The name of the xml file for the current test run.
        Type : [String]

    .Parameter logDir
        The path of the folder containing the log files
        Type : [String]

    .ReturnValue
        A string containing all the summary message from all
        VMs in the current test run.

    .Example
        SummaryToString $testConfig $myStartTime $myXmlTestFile
    #>

    $str = "<br />Test Results Summary<br />"
    $str += "LISA test run on " + $startTime
    $str += "<br />XML file: $xmlFilename<br /><br />"

    #
    # Add information about the host running ICA to the e-mail summary
    #
    $str += "<pre>"
    foreach($vm in $xmlConfig.config.VMs.vm)
    {
        $str += $vm.emailSummary + "<br />"
    }

    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)

    #
    # Check to see if the provided log path is absolute
    #
    if ([System.IO.Path]::IsPathRooted($logDir))
    {
        $logPath = $logDir
    }
    else
    {
        $logPath = (Get-Item -Path ".\" -Verbose).FullName + "\" + $logDir
    }

    $str += "Logs can be found at " + $logPath + "\" + $fname + "-" + $startTime.ToString("yyyyMMdd-HHmmss") + "<br /><br />"
    $str += "</pre><br />"
    return $str
}

#####################################################################
#
# SendEmail
#
#####################################################################
function SendEmail([XML] $xmlConfig, [DateTime] $startTime, [string] $xmlFilename, [string] $logDir)
{
    <#
    .Synopsis
        Send an e-mail message with test summary information.

    .Description
        Collect the test summary information from each VM.  Send an
        eMail message with this summary information to emailList defined
        in the xml config file.

    .Parameter xmlConfig
        The parsed XML from the test xml file
        Type : [System.Xml]

    .Parameter logDir
        The path of the folder containing the log files
        Type : [String]

    .ReturnValue
        none

    .Example
        SendEmail $myConfig
    #>

    $to = @()
    foreach($r in $xmlConfig.config.global.email.recipients.to)
    {
        $to = $to + $r
    }

    $from = $xmlConfig.config.global.email.Sender
    $subject = $xmlConfig.config.global.email.Subject + " " + $startTime
    $smtpServer = $xmlConfig.config.global.email.smtpServer
    $fname = [System.IO.Path]::GetFilenameWithoutExtension($xmlFilename)

    $body = SummaryToString $xmlConfig $startTime $fname
    $body = $body.Replace("Aborted", '<em style="background:Aqua; color:Red">Aborted</em>')
    $body = $body.Replace("Failed", '<em style="background:Yellow; color:Red">Failed</em>')

    #
    # Check to see if the provided log path is absolute
    #
    if ([System.IO.Path]::IsPathRooted($logDir))
    {
        $logPath = $logDir
    }
    else
    {
        $logPath = (Get-Item -Path ".\" -Verbose).FullName + "\" + $logDir
    }

    $str += "Logs can be found at " + $logPath + "\" + $fname + "-" + $startTime.ToString("yyyyMMdd-HHmmss") + "<br /><br />"

    Send-mailMessage -to $to -from $from -subject $subject -body $body -BodyAsHtml -smtpserver $smtpServer
}

#####################################################################
#
# ShutDownVM
#
#####################################################################
function ShutDownVM([System.Xml.XmlElement] $vm)
{
    <#
    .Synopsis
        Stop the VM

    .Description
        Try to send a halt command to the VM.  If this fails,
        use the HyperV library Stop-VM call to try and stop
        the VM.  If the VM is already stopped, do nothing.

    .Parameter vm
        An xml node representing the VM.
        Type : [System.Xml.XmlElement]

    .ReturnValue
        none

    .Example
        ShutDownVM $myVM
    #>

    $v = Get-VM -vm $($vm.vmName) -ComputerName $($vm.hvServer)
    if ($($v.State) -ne "Off")
    {
        Stop-VM $($vm.vmName) -ComputerName $($vm.hvServer) -Force
        if ($? -ne $true)
        {
            LogMsg 0 "Warn : $($vm.vmName) did not shutdown gracefully. Forcing VM TurnOff."
            Stop-VM $($vm.vmName) -ComputerName $($vm.hvServer) -TurnOff
        }
    }
}

#####################################################################
#
# RunPSScript
#
#####################################################################
function RunPSScript([System.Xml.XmlElement] $vm, [string] $scriptName, [XML] $xmlData, [string] $mode, [string] $logFilename)
{
    <#
    .Synopsis
        Run a separate PowerShell script.

    .Description
        Run the specified PowerShell script.

    .Parameter vmName
        Name of the VM
        Type : [String]

    .Parameter scriptName
        Name of the PowerShell script to be run
        Type : [String]

    .Parameter logFilename
        The name of the file to write output to.
        Type : [String]

    .ReturnValue
        True or false to indicate if the script ran successfully or not.
        Output type: [Boolean]

    .Example
        RunPSScript "fed13" "hvServer1" ".\AddNic.ps1" $testData ".\myLog.log"
    #>

    $retVal = $False
    $scriptMode = "unknown"

    #
    # Check the input arguments
    #
    if (-not $vm)
    {
        logMsg 0 "Error: RunPSScript() was passed a numm VM"
        return $False
    }

    if (-not $scriptName)
    {
        logMsg 0 ("Error: RunPSScript($vmName, $hvServer, null) was passed a null scriptName")
        return $False
    }

    if (-not $xmlData)
    {
        logMsg 0 ("Error: RunPSScript($vmName, $hvServer, $scriptName, testData, null) was passed null test data")
        return $False
    }

    if ($mode)
    {
        $scriptMode = $mode
    }

    if (-not (test-path -path $scriptName))
    {
        logMsg 0 ("Error: RunPSScript() script file '$scriptName' does not exist.")
        return $False
    }

    $vmName = $vm.vmName
    $hvServer = $vm.hvServer
    $testData = GetTestData $vm.currentTest $xmlData
    logMsg 6 ("Info : RunPSScript($vmName, $hvServer, $scriptName)")

    if (-not $testData)
    {
        if ([string]::Compare($vm.role, "SUT", $true) -eq $true)
        {
            LogMsg 0 "$($vm.vmName) Unable to collect test data for test $($vm.currentTest)"
            return $False
        }
    }

    #
    # Create an string of test params, separated by semicolons - ie. "a=1;b=x;c=5;"
    #
    $params = CreateTestParamString $vm $xmlData
    $params += "scriptMode=${scriptMode};"
    $params += "TestLogDir=${testDir};"
    $params += "sshKey=$($vm.sshKey);"
    $params += "ipv4=$($vm.ipv4);"

    #
    # Invoke the setup/cleanup script
    #
    $cmd = "$scriptName -vmName $vmName -hvServer $hvServer"

    #
    # Only add the testParams if something was specified, and it appears reasonable
    # Min param length is 3 -ie.  "a=1"
    #
    if ($params.Length -gt 2 -and $params.Contains("="))
    {
        $cmd += " -testParams `"$params`""
    }

    LogMsg 6 ("Info : Invoke-Expression $cmd")
    $sts = Invoke-Expression $cmd

    $numItems = $sts.length
    LogMsg 6 "Debug: $vmName - Invoke-Expression returned array with $($sts.length) elements"

    if ($sts[$numItems - 1] -eq "True")
    {
        $retVal = $true
    }

    #
    # Write script output into log file
    #
    for($i=0; $i -lt $numItems; $i++)
    {
        logMsg 3 ("Info :    $vmName - $($sts[$i])")
    }

    return $retVal
}

#####################################################################
#
# TestPort
#
#####################################################################
function TestPort ([String] $serverName, [Int] $port=22, [Int] $to=3)
{
    <#
    .Synopsis
        Check to see if a specific TCP port is open on a server.
    .Description
        Try to create a TCP connection to a specific port (22 by default)
        on the specified server. If the connect is successful return
        true, false otherwise.
    .Parameter Host
        The name of the host to test
    .Parameter Port
        The port number to test. Default is 22 if not specified.
    .Parameter Timeout
        Timeout value in seconds
    .Example
        Test-Port $serverName
    .Example
        Test-Port $serverName -port 22 -timeout 5
    #>

    $retVal = $False
    $timeout = $to * 1000

    #
    # Try an async connect to the specified machine/port
    #
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($serverName,$port,$null,$null)

    #
    # Wait for the connect to complete. Also set a timeout
    # so we don't wait all day
    #
    $connected = $iar.AsyncWaitHandle.WaitOne($timeout,$false)

    # Check to see if the connection is done
    if($connected)
    {
        #
        # Close our connection
        #
        try
        {
            $sts = $tcpclient.EndConnect($iar)
            $retVal = $true
        }
        catch
        {
            # Nothing we need to do...
            $msg = $_.Exception.Message
        }

        #if($sts)
        #{
        #    $retVal = $true
        #}
    }
    $tcpclient.Close()

    return $retVal
}

#####################################################################
#
# UpdateState
#
#####################################################################
function UpdateState([System.Xml.XmlElement] $vm, [string] $newState)
{
    <#
    .Synopsis
        Update the VM's state in the XML object representing the VM.
    .Description
        Update the VMs state in the XML object, log a message,
        and update the timestamp of the last state transition.
    .Parameter vm
        The XML object representing the VM who's state needs updating.
    .Parameter newState
        The VMs new state.
    .ReturnValue
        None
    #>

    $oldState = $vm.state
    $vm.state = $newState
    LogMsg 2 "Info : $($vm.vmName) transitioned from ${oldState} to $($vm.state)"
    $vm.stateTimestamp = [DateTime]::Now.ToString()
}

#####################################################################
#
# GetFileFromVM()
#
#####################################################################
function GetFileFromVM([System.Xml.XmlElement] $vm, [string] $remoteFile, [string] $localFile)
{
    <#
    .Synopsis
        Copy a file from a remote system, the VM, to a local copy.
    .Description
        Use SSH to copy a file from a remote system, to a local file,
        possibly renaming the file in the process.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter remoteFile
        The name, including path, of the file on the remote system.
    .Parameter localFile
        The name, including path, the file is to be copied to.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
    #>

    $retVal = $False

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    #bin\pscp -q -i ssh\${sshKey} root@${hostname}:${remoteFile} $localFile
    #if ($?)

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} root@${hostname}:${remoteFile} ${localFile}" -PassThru -NoNewWindow -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    $process | Wait-process -timeout 4 -ErrorAction 0 -ErrorVariable hangFlag
    if ($hangFlag) {
        $process | kill
    }
    if ($process.ExitCode -eq 0)
    {
        $retVal = $True
    }
    else
    {
        LogMsg 1 "ERROR: GetFileFromVM failed. Error message from pscp: "
        $error = Get-Content .\lisaErr.tmp
        LogMsg 1 $error
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}

#####################################################################
#
# SendFileToVM()
#
#####################################################################
function SendFileToVM([System.Xml.XmlElement] $vm, [string] $localFile, [string] $remoteFile)
{
    <#
    .Synopsis
        Copy a file To a remote system, the VM, to a local copy.
    .Description
        Use SSH to copy a file to a remote system.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter localFile
        The name of the file is to be copied to the remote system.
    .Parameter remoteFile
        The name, including path, of the file on the remote system.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
   #>

    $retVal = $False

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $recurse = ""
    if (test-path -path $localFile -PathType Container )
    {
        $recurse = "-r"
    }

    #bin\pscp -q $recurse -i ssh\${sshKey} $localFile root@${hostname}:${remoteFile}
    #if ($?)

    $process = Start-Process bin\pscp -ArgumentList "-i ssh\${sshKey} ${localFile} root@${hostname}:${remoteFile}" -PassThru -NoNewWindow -Wait -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    if ($process.ExitCode -eq 0)
    {
        $retVal = $True
    }
    else
    {
        LogMsg 1 "ERROR: SendFileToVM failed. Error message from pscp: "
        $error = Get-Content .\lisaErr.tmp
        LogMsg 1 $error
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}

#####################################################################
#
# SendCommandToVM()
#
#####################################################################
function SendCommandToVM([System.Xml.XmlElement] $vm, [string] $command)
{
    <#
    .Synopsis
        Run a command on a remote system.
    .Description
        Use SSH to run a command on a remote system.
    .Parameter vm
        The XML object representing the VM to copy from.
    .Parameter command
        The command to be run on the remote system.
    .ReturnValue
        True if the file was successfully copied, false otherwise.
    #>

    $retVal = $False

    $vmName = $vm.vmName
    $hostname = $vm.ipv4
    $sshKey = $vm.sshKey

    $process = Start-Process bin\plink -ArgumentList "-i ssh\${sshKey} root@${hostname} ${command}" -PassThru -NoNewWindow -redirectStandardOutput lisaOut.tmp -redirectStandardError lisaErr.tmp
    $commandTimeout = 30
    while(!$process.hasExited)
    {
        LogMsg 8 "Waiting 1 second to check the process status for Command = '$command'."
        sleep 1
        $commandTimeout -= 1
        if ($commandTimeout -le 0)
        {
            LogMsg 3 "Killing process for Command = '$command'."
            $process.Kill()
            LogMsg 0 "Error: Send command to VM $vmName timed out for Command = '$command'"
        }
    }

    if ($commandTimeout -gt 0)
    {
        $retVal = $True
        LogMsg 2 "Success: $vmName successfully sent command to VM. Command = '$command'"
    }

    del lisaOut.tmp -ErrorAction "SilentlyContinue"
    del lisaErr.tmp -ErrorAction "SilentlyContinue"

    return $retVal
}

#####################################################################
#
# TestRemotePath
#
#####################################################################
function TestRemotePath ([String] $path, [String] $hvServer)
{
    <#
    .Synopsis
        Check to see if a file exists on a remote HyperV server
    .Description
        User WMI to see if a file exists on a remote HyperV server
    .Parameter path
        The name of the host to test
    .Parameter hvServer
        The name, or IP address, of the HyperV server
    .Example
        TestRemoteFile "C:\HyperV\VHDs\test.vhd" "myHvServer"
    .Example
        TestRemoteFile -path "C:\HyperV\VHDs\test.vhd" -hvServer "myHvServer"
    #>

    $retVal = $False

    if (-not $path)
    {
        return $False
    }

    if (-not $hvServer)
    {
        return $False
    }

    #
    # Create a FileInfo object from the path string
    #
    try
    {
        $fileInfo = [System.IO.FileInfo]"$path"
        if (-not $fileInfo)
        {
            return $False
        }
    }
    catch
    {
        return $False
    }

    #
    # The WMI call requires the filename to be broken up into the following elements:
    #     drive
    #     directory path
    #     filename
    #     filename extension
    #
    $fileName = $fileInfo.BaseName
    $extension = $null
    if ( ($fileInfo.Extension).Length -gt 1)
    {
        $extension = ($fileInfo.Extension).SubString(1)
    }

    $directory = $null
    if ( ($fileInfo.DirectoryName).Length -gt 0 )
    {
        $directory = $fileInfo.DirectoryName + "\"
    }

    $elements = $directory.Split(":")
    if ($elements -isnot [array])
    {
        return $False
    }

    if ($elements.Length -ne 2)
    {
        return $False
    }

    $drive = $elements[0] + ":"
    if ($drive.Length -ne 2)
    {
        return $False
    }

    #
    # The WMI call requires the directory path have double spaces - i.e.
    #   \\dir\\subdir\\subdir\\
    #
    $dirPath = ($elements[1]).Replace("\", "\\")

    $filter = "drive=`"$drive`""
    if ($dirPath)
    {
        $filter += " and path=`"$dirPath`""
    }

    if ($fileName)
    {
        $filter += " and filename=`"$fileName`""
    }

    if ($extension)
    {
        $filter += " and extension=`"$extension`""
    }

    #"Info : TestRemotePath filter = $filter"

    $fileInfo = gwmi CIM_dataFile -filter $filter -computer $hvServer

    if ($fileInfo)
    {
        $retVal = $True
    }

    return $retVal
}

#####################################################################
#
# Test-Admin()
#
#####################################################################
function Test-Admin ()
{
    <#
    .Synopsis
        Check if process is running as an Administrator
    .Description
        Test if the user context this process is running as
        has Administrator privileges
    .Example
        Test-Admin
    #>
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

#######################################################################
#
# CreateTestParamString()
#
#######################################################################
function CreateTestParamString([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Create a string with all the test parameters.
    .Description
        Create a string and appent each test parameter.  Each
        test parameter is separated by a semicolon.
    .Parameter $vm
        The XML element for the VM under test.
    .Parameter $xmlData
        The XML Document of the test data.
    .Example
        CreateTestParamString $testVM $xmlTestData
    #>

    $tp = ""
    $testData = GetTestData $($vm.currentTest) $xmlData

    if ($xmlData.config.global.testParams -or $testdata.testParams -or $vm.testParams)
    {
        #
        # First, add any global testParams
        #
        if ($xmlData.config.global.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding glogal test params"
            foreach ($param in $xmlData.config.global.testParams.param)
            {
                $tp += $param + ";"
            }
        }

        #
        # Next, add any test specific testParams
        #
        if ($testdata.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding testparmas for test $($testData.testName)"
            foreach ($param in $testdata.testParams.param)
            {
                $tp += $param + ";"
            }
        }

        #
        # Now, add VM specific testParams
        #
        if ($vm.testParams)
        {
            LogMsg 9 "Info : $($vm.vmName) Adding VM specific params"
            foreach ($param in $vm.testParams.param)
            {
                $tp += $param + ";"
            }
        }
    }

    #
    # Add the iteration information if test case is being iterated
    #
    if ($vm.iteration -ne "-1")
    {
        $iterationParam = GetIterationParam $vm $xmlData
        if ($iterationParam)
        {
            $tp += "iteration=$($vm.iteration);"

            if ($iterationParam -ne "")
            {
                $tp += "iterationParam=${iterationParam};"
            }
        }
        else
        {
            LogMsg 0 "Error: $($vm.vmName) bad iteration param for test $($vm.currentTest)"
        }
    }

    #
    # Include the test log directory path
    #
    $tp += "rootDir=$PWD;"

    #
    # Include the test log directory path
    #
    $tp += "TestLogDir=${testDir};"

    #
    # Include the test name too , to redirect remote scripts log to it .
    #
    $testname   = $vm.currentTest
    $tp += "TestName=${testname};"

    return $tp
}

#######################################################################
#
# UpdateCurrentTest()
#
#######################################################################
function UpdateCurrentTest([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Update the vm.currentTest attribute.
    .Description
        Determine the name of the next test case in the test suite,
        then update the VMs currentTest attribute with the new
        test name.
    .Parameter $vm
        The XML element for the VM under test.
    .Parameter $xmlData
        The XML Document of the test data.
    .Example
        UpdateCurrentTest $testVM $xmlTestData
    #>

    if (-not $vm)
    {
        LogMsg 0 "Error: UpdateCurrentTest() received a null VM object"
        return
    }

    if (-not $xmlData)
    {
        LogMsg 0 "Error: UpdateCurrentTest() received a null xmlData object"
        return
    }

    #actually this is the previous test. here we need to pick up next new test if existing
    #if previous test has been marked as "done" - for example, test failed and its XML defined to Abort test onError
    $previousTest = $vm.currentTest
    if ($previousTest -eq "done")
    {
        return
    }

    $previousTestData = GetTestData $previousTest $xmlData
    #$nextTest = $currentTest

    #if previous test failed and the XML setting is set to Abort on "onError"
    # then try to quite Lisa
    if ( (($vm.testCaseResults -eq $Aborted) -or ($vm.testCaseResults -eq $Failed)) -and $previousTestData.onError -eq "Abort")
    {
        $vm.currentTest = "done"
        return
    }

    if ($previousTestData.maxIterations)
    {
         $iterationCount = (([int] $vm.iteration) + 1)
         $vm.iteration = $iterationCount.ToString()
         if ($iterationCount -ge [int] $previousTestData.maxIterations)
         {
             $nextTest = GetNextTest $vm $xmlData
             $vm.currentTest = [string] $nextTest
             $testData = GetTestData $vm.currentTest $xmlData
             if ($testData.maxIterations)
             {
                 $vm.iteration = "0"
             }
             else
             {
                 $vm.iteration = "-1"
             }
         }
    }
    else
    {
        $nextTest = GetNextTest $vm $xmlData
        $vm.currentTest = [string] $nextTest
        $testData = GetTestData $vm.currentTest $xmlData
        if ($testData.maxIterations)
        {
            $vm.iteration = "0"
        }
        else
        {
            $vm.iteration = "-1"
        }
    }

    # Reset test results if we've moved on to the next test case
    if ($vm.currentTest -ne "done")
    {
        $vm.testCaseResults = "none"
        $vm.individualResults += "0"
    }
}

#######################################################################
#
# GetIterationparam()
#
#######################################################################
function GetIterationParam([System.Xml.XmlElement] $vm, [XML] $xmlData)
{
    <#
    .Synopsis
        Return the iteration parameter.
    .Description
        Test case iteration is a feature that is not completed yet.
        The idea is to run a test case n number of times.  Each
        time the test is run, the iteration count is incremented.
        The iteration value is passed as a test parameter.
    .Parameter $vm
        The XML element for the VM under test.
    .Parameter $xmlData
        The XML Document of the test data.
    .Output
        $null on error
        if no iteration param
        'param if valid iteration param
    .Example
        GetIterationParam $testVM $xmlTestData
    #>

    $iterationParam = $null

    if (-not $VM)
    {
        LogMsg 0 "Error: GetIterationParam() received a null VM object"
        return $null
    }

    if (-not $xmlData)
    {
        LogMsg 0 "Error: GetIterationParam() received a null xmlData object"
        return $null
    }

    $testData = GetTestData $vm.currentTest $xmlData
    if ($testData)
    {
        if ($testData.maxIterations)
        {
            $iterationParam = ""

            if ($testData.iterationParams)
            {
                if ($testData.iterationParams.param.count -eq 1)
                {
                    $iterationParam = $testData.iterationParams.param
                }
                else
                {
                    if ($testData.iterationParams.param.count -eq $testData.maxIterations)
                    {
                        $iterationNumber = [int] $vm.iteration
                        $iterationParam = ($testData.iterationParams.param[$iterationNumber]).ToString()
                    }
                    else
                    {
                        LogMsg 0 "Error: GetIterationParam() incorrect number of iterationParams for test $($vm.currentTest)"
                        $iterationParam = $null
                    }
                }
            }
        }
        else
        {
            LogMsg 0 "Error: GetIterationParam() was called for a non-iterated test case"
        }
    }
    else
    {
        LogMsg 0 "Error: GetIterationParam() could not find test data for test $($vm.currentTest)"
    }

    return $iterationParam
}

#######################################################################
#
# GetIPv4ViaHyperV()
#
# Description:
#    Look at the IP addresses on each NIC the VM has.  For each
#    address, see if it in IPv4 address and then see if it is
#    reachable via a ping.
#
#######################################################################
function GetIPv4ViaHyperV([String] $vmName, [String] $server)
{
    <#
    .Synopsis
        Use the Hyper-V network cmdlets to retrieve a VMs IPv4 address.
    .Description
        Look at the IP addresses on each NIC the VM has.  For each
        address, see if it in IPv4 address and then see if it is
        reachable via a ping.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter server
        Name of the server hosting the VM
    .Example
        GetIpv4ViaHyperV $testVMName $serverName
    #>

    $vm = Get-VM -Name $vmName -ComputerName $server -ErrorAction SilentlyContinue
    if (-not $vm)
    {
        Write-Error -Message "GetIPv4ViaHyperV: Unable to create VM object for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $networkAdapters = $vm.NetworkAdapters
    if (-not $networkAdapters)
    {
        Write-Error -Message "GetIPv4ViaHyperV: No network adapters found on VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    foreach ($nic in $networkAdapters)
    {
        $ipAddresses = $nic.IPAddresses
        if (-not $ipAddresses)
        {
            Continue
        }

        foreach ($address in $ipAddresses)
        {
            # Ignore address if it is not an IPv4 address
            $addr = [IPAddress] $address
            if ($addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork)
            {
                Continue
            }

            # Ignore address if it a loopback address
            if ($address.StartsWith("127."))
            {
                Continue
            }

            # See if it is an address we can access
            $ping = New-Object System.Net.NetworkInformation.Ping
            $sts = $ping.Send($address)
            if ($sts -and $sts.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            {
                return $address
            }
        }
    }

    Write-Error -Message "GetIPv4ViaHyperV: No IPv4 address found on any NICs for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $null
}

#######################################################################
#
# GetIPv4ViaICASerial()
#
#######################################################################
function GetIPv4ViaICASerial( [String] $vmName, [String] $server)
{
    <#
    .Synopsis
        Use ICASerial to retrieve the VMs IPv4 address.
    .Description
        Use ICASerial.exe to read the IP address from the VM.
        ICASerial requires the icadaemon be running on the VM.
        ICASerial and ICADaemon communicate via a VMs COM port.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter server
        Name of the server hosting the VM
    .Example
        GetIPv4ViaICASerial $testVMName $serverName
    #>

    $ipv4 = $null

    #
    # Make sure icaserial.exe exists
    #
    if (-not (Test-Path .\bin\icaserial.exe))
    {
        Write-Error -Message "GetIPv4ViaICASerial: File .\bin\icaserial.exe not found" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    #
    # Get the MAC address of the VMs NIC
    #
    $vm = Get-VM -Name $vmName -ComputerName $server -ErrorAction SilentlyContinue
    if (-not $vm)
    {
        Write-Error -Message "GetIPv4ViaICASerial: Unable to get VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $macAddr = $vm.NetworkAdapters[0].MacAddress
    if (-not $macAddr)
    {
        Write-Error -Message "GetIPv4ViaICASerial: Unable to determine MAC address of first NIC" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    #
    # Get the Pipe name for COM1
    #
    $pipeName = $vm.ComPort2.Path
    if (-not $pipeName)
    {
        Write-Error -Message "GetIPv4ViaICASerial: VM ${vmName} does not have a pipe associated with COM1" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    #
    # Use ICASerial and ask the VM for it's IPv4 address
    #
    # Note: ICASerial is returning an array of strings rather than a single
    #       string.  Use the @() to force the response to be an array.  This
    #       will prevent breaking the following code when ICASerial is fixed.
    #       Remove the @() once ICASerial is fixed.
    #
    $timeout = "5"
    $response = @(bin\icaserial SEND $pipeName $timeout "get ipv4 macaddr=${macAddr}")
    if ($response)
    {
        #
        # The array indexing on $response is because icaserial returning an array
        # To be removed once icaserial is corrected
        #
        $tokens = $response[0].Split(" ")
        if ($tokens.Length -ne 3)
        {
            Write-Error -Message "GetIPv4ViaICASerial: bad ICAserial response: ${response}" -Category ReadError -ErrorAction SilentlyContinue
            return $null
        }

        if ($tokens[0] -ne "ipv4")
        {
            Write-Error -Message "GetIPv4ViaICASerial: ICAserial response does not match request: ${response}" -Category ObjectNotFound -ErrorAction SilentlyContinue
            return $null
        }

        if ($tokens[1] -ne "0")
        {
            Write-Error -Message "GetIPv4ViaICASerial: ICAserical returned an error: ${response}" -Category ReadError -ErrorAction SilentlyContinue
            return $null
        }

        $ipv4 = $tokens[2].Trim()
    }

    return $ipv4
}

#######################################################################
#
# GetIPv4ViaKVP()
#
#######################################################################
function GetIPv4ViaKVP( [String] $vmName, [String] $server)
{
    <#
    .Synopsis
        Ise KVP to retrieve the VMs IPv4 address.
    .Description
        Do a KVP intrinsic data exchange with the VM and
        extract the IPv4 address from the returned KVP data.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter server
        Name of the server hosting the VM
    .Example
        GetIpv4ViaKVP $testVMName $serverName
    #>

    $vmObj = Get-WmiObject -Namespace root\virtualization\v2 -Query "Select * From Msvm_ComputerSystem Where ElementName=`'$vmName`'" -ComputerName $server
    if (-not $vmObj)
    {
        Write-Error -Message "GetIPv4ViaKVP: Unable to create Msvm_ComputerSystem object" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $kvp = Get-WmiObject -Namespace root\virtualization\v2 -Query "Associators of {$vmObj} Where AssocClass=Msvm_SystemDevice ResultClass=Msvm_KvpExchangeComponent" -ComputerName $server
    if (-not $kvp)
    {
        Write-Error -Message "GetIPv4ViaKVP: Unable to create KVP exchange object" -Category ObjectNotFound -ErrorAction SilentlyContinue
        return $null
    }

    $rawData = $Kvp.GuestIntrinsicExchangeItems
    if (-not $rawData)
    {
        Write-Error -Message "GetIPv4ViaKVP: No KVP Intrinsic data returned" -Category ReadError -ErrorAction SilentlyContinue
        return $null
    }

    $name = $null
    $addresses = $null

    foreach ($dataItem in $rawData)
    {
        $found = 0
        $xmlData = [Xml] $dataItem
        foreach ($p in $xmlData.INSTANCE.PROPERTY)
        {
            if ($p.Name -eq "Name" -and $p.Value -eq "NetworkAddressIPv4")
            {
                $found += 1
            }

            if ($p.Name -eq "Data")
            {
                $addresses = $p.Value
                $found += 1
            }

            if ($found -eq 2)
            {
                $addrs = $addresses.Split(";")
                foreach ($addr in $addrs)
                {
                    if ($addr.StartsWith("127."))
                    {
                        Continue
                    }
                    return $addr
                }
            }
        }
    }

    Write-Error -Message "GetIPv4ViaKVP: No IPv4 address found for VM ${vmName}" -Category ObjectNotFound -ErrorAction SilentlyContinue
    return $null
}

#######################################################################
#
# GetIPv4()
#
#######################################################################
function GetIPv4([String] $vmName, [String] $server)
{
    <#
    .Synopsis
        Retrieve the VMs IPv4 address
    .Description
        Try the various methods to extract an IPv4 address from a VM.
    .Parameter vmName
        Name of the VM to retrieve the IP address from.
    .Parameter server
        Name of the server hosting the VM
    .Example
        GetIPv4 $testVMName $serverName
    #>

    $errMsg = $null
    $addr = GetIPv4ViaKVP $vmName $server
    if (-not $addr)
    {
        $errMsg += $error[0].Exception.Message

        $addr = GetIPv4ViaHyperV $vmName $server
        if (-not $addr)
        {
            $errMsg += ("`n" + $error[0].Exception.Message)

            $addr = GetIPv4ViaICASerial $vmName $server
            if (-not $addr)
            {
                $errMsg += ("`n" + $error[0].Exception.Message)
                Write-Error -Message ("GetIPv4: Unable to determine IP address for VM ${vmName}`n" + $errmsg) -Category ReadError -ErrorAction SilentlyContinue
                return $null
            }
        }
    }

    return $addr
}

#######################################################################
#
# VerifyTestResourcesExist()
#
#######################################################################
function VerifyTestResourcesExist([System.Xml.XmlElement] $vm, [System.Xml.XmlElement] $testData)
{
    $retVal = $True

    $vmName = $vm.vmName
    $testName = $testData.testName

    #
    # Verify the VM resource <sshKey>
    #
    if ($vm.sshKey)
    {
        $sshKey = ".\ssh\$($vm.sshKey)"
        if (-not (Test-Path -Path "${sshKey}"))
        {
            LogMsg 0 "Error: ${vmName} - the VM sshkey '${sshKey}' does not exist"
            $retVal = $False
        }
    }

    #
    # Verify the VM resource <preStartConfig>
    #
    if ($vm.preStartConfig)
    {
        if ($vm.preStartConfig.file)
        {
            foreach ($preStartScript in $vm.preStartConfig.file)
            {
                if (-not (Test-Path -Path "${preStartScript}"))
                {
                    LogMsg 0 "Error: $($vm.vmName) - the VM preStartConfig script '${preStartScript}' does not exist"
                    $retVal = $False
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($vm.preStartConfig)"))
            {
                LogMsg 0 "Error: $($vm.vmName) - the VM preStartConfig script '${preStartScript}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <setupScript>
    #
    if ($testData.setupScript)
    {
        if ($testData.setupScript.file)
        {
            foreach ($script in $testData.setupScript.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the setup script '${script}' for test '${testName}' does not exist"
                    $retVal = $False
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.setupScript)"))
            {
                LogMsg 0 "Error: ${vmName} - the setup script '$($testData.setupScript)' for test '${testName}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <preTest>
    #
    if ($testData.preTest)
    {
        if ($testData.preTest.file)
        {
            foreach ($script in $testData.preTest.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the PreTest script '${script}' for test '${testName}' does not exist"
                    $retVal = $False
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.preTest)"))
            {
                LogMsg 0 "Error: ${vmName} - the PreTest script '$($testData.preTest)' for test '${testName}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <postTest>
    #
    if ($testData.postTest)
    {
        if ($testData.postTest.file)
        {
            foreach ($script in $testData.postTest.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the PostTest script '${script}' for test '${testName}' does not exist"
                    $retVal = $False
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.postTest)"))
            {
                LogMsg 0 "Error: ${vmName} - the PostTest script '$($testData.postTest)' for test '${testName}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <cleanupScript>
    #
    if ($testData.cleanupScript)
    {
        if ($testData.cleanupScript.file)
        {
            foreach ($script in $testData.cleanupScript.file)
            {
                if (-not (Test-Path -Path "${script}"))
                {
                    LogMsg 0 "Error: ${vmName} - the cleanup script '${script}' for test '${testName}' does not exist"
                    $retVal = $False
                }
            }
        }
        else
        {
            if (-not (Test-Path -Path "$($testData.cleanupScript)"))
            {
                LogMsg 0 "Error: ${vmName} - the cleanup script '$($testData.cleanupScript)' for test '${testName}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <files>
    #
    if ($testData.files)
    {
        $files = ($testData.files).split(",")
        foreach ($f in $files)
        {
            $testFile = $f.trim()
            if (-not (Test-Path -Path "${testFile}"))
            {
                LogMsg 0 "Error: ${vmName} - the test file '${testFile}' for test '${testName}' does not exist"
                $retVal = $False
            }
        }
    }

    #
    # Verify the test resource <testScript> when it is a .ps1
    #
    if (($testData.testScript).EndsWith(".ps1"))
    {
        $testFile = $testData.TestScript
        if (-not (Test-Path -Path "${testFile}"))
        {
            LogMsg 0 "Error: ${vmName} - the test script '${testFile}' for test '${testName}' does not exist"
            $retVal = $False
        }
    }

    return $retVal
}

#####################################################################
#
# checkHostVersion
#
#####################################################################
function checkHostVersion([XML] $xmlData)
{
    <#
    .Synopsis
        Check OS version dependency defined in the hostVersion tag.

    .Description
        Check if the host version dependency is met.

    .Parameter $xmlData
        The parsed XML from the test xml file
        Type : [System.Xml]

    .ReturnValue
        [Boolean]

    .Example
        checkHostVersion $xmlConfig
    #>
    $retVal = $True
    $hostVersionDependency =  $xmlConfig.config.global.dependency.hostVersion
    $match = $hostVersionDependency -match '^\s*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{3,})[0-9.]*$'
    if ($match -eq $True)
    {
        $dependencyVersion = @{major=[int]$Matches[1];minor=[int]$Matches[2];build=[int]$Matches[3]}
    }
    else
    {
        LogMsg 0 "Error: Could not parse provided dependency hostVersion: '${hostVersionDependency}'."
        return $False
    }

    foreach( $vm in $xmlData.config.VMs.vm )
    {
        $hostVersion = (Get-WmiObject -class Win32_OperatingSystem -ComputerName $($vm.hvServer)).Version
        $match = $hostVersion -match '^\s*([0-9]{1,2})\.([0-9]{1,2})\.([0-9]{3,})[0-9.]*$'
        if ($match -eq $True)
        {
            $currentVersion = @{major=[int]$Matches[1];minor=[int]$Matches[2];build=[int]$Matches[3]}
        }
        else
        {
            LogMsg 0 "Error: Could not parse host '$($vm.hvServer)' version: '${hostVersion}'."
            return $False
        }
        if ($currentVersion.build -ge $dependencyVersion.build)
        {
            if ($currentVersion.major -eq $dependencyVersion.major)
            {
                if ($currentVersion.minor -ge $dependencyVersion.minor)
                {
                    continue
                }
            }
            elseif ($currentVersion.major -gt $dependencyVersion.major)
            {
                continue
            }
        }
        LogMsg 0 "Error: $($vm.hvServer) build or version '$hostVersion' is lower than dependency '$hostVersionDependency'"
        $retVal = $False
    }
    return $retVal
}

#####################################################################
#
# TakeConsoleScreenShot
#
#####################################################################
function TakeConsoleScreenShot
{
    param
    (
        $VM,
        $x,
        $y
    )
    # This function captures a screenshot of the VM console
    # It's used when the VM enters DiagnoseHungSystem state

    $VMMS = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemManagementService

    # Get screenshot
    $image = $VMMS.GetVirtualSystemThumbnailImage($VMCS, $x, $y).ImageData

    # Transform into bitmap
    $BitMap = New-Object System.Drawing.Bitmap -Args $x,$y,Format16bppRgb565
    $Rect = New-Object System.Drawing.Rectangle 0,0,$x,$y
    $BmpData = $BitMap.LockBits($Rect,"ReadWrite","Format16bppRgb565")
    [System.Runtime.InteropServices.Marshal]::Copy($Image, 0, $BmpData.Scan0, $BmpData.Stride*$BmpData.Height)

    $BitMap.UnlockBits($BmpData)

    return $BitMap
}
