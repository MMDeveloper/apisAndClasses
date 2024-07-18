class fixedWidthRecordsGenerator {
    #full path and filename to write to
    [string] $pathAndFilename = $null

    #ordered dictionary of field names and their properties
    [ordered] $rowLayout = @{}

    #array of formatted records to be written
    [array] $recordsToWrite = @()

    #number of records to accumulate before flushing to disk
    [int] $flushAfter = 100

    fixedWidthRecordsGenerator($methodParams) {
        if ($null -eq $methodParams.pathAndFilename) {
            throw 'pathAndFilename is required'
        }

        if ($null -eq $methodParams.rowLayout -or $methodParams.rowLayout.gettype().Name -notlike 'OrderedDictionary') {
            throw 'rowLayout is a required OrderedDictionary'
        }

        $this.pathAndFilename = $methodParams.pathAndFilename
        $this.rowLayout = $methodParams.rowLayout
    }

    [object] addRecord([hashtable] $record) {
        $recordToAdd = ''
        $addRecord = $true

        $returnRecord = @{
            added  = $addRecord
            errors = @()
        }

        #check validations
        foreach ($key in $this.rowLayout.Keys) {
            if ($null -ne $this.rowLayout[$key].validate) {
                if ($null -ne $this.rowLayout[$key].validate -and $this.rowLayout[$key].validate -is [scriptblock]) {
                    $dataValue = $this.convertToString($record[$key])
                    $ret = & $this.rowLayout[$key].validate $dataValue

                    <#if ($key -like 'workEmailAddress' -or $key -like 'personalEmailAddress') {
                        Write-Host "Validation for $key returned $($ret.valid); data '$($dataValue)' is a $($dataValue.gettype())"
                    }#>

                    if ($ret.valid -eq $false) {
                        $returnRecord.errors += $ret.errors
                        $addRecord = $false
                    }
                }
            }
        }

        #if all validations pass, add the record
        if ($addRecord -eq $true) {
            foreach ($key in $this.rowLayout.Keys) {
                $dataValue = $this.convertToString($record[$key])
                if ($dataValue.Length -lt $this.rowLayout[$key].width) {
                    switch ($this.rowLayout[$key].padSide) {
                        'left' {
                            $recordToAdd += $dataValue.PadLeft($this.rowLayout[$key].width, $this.rowLayout[$key].padWith)
                        }
                        'right' {
                            $recordToAdd += $dataValue.PadRight($this.rowLayout[$key].width, $this.rowLayout[$key].padWith)
                        }
                        default {
                            $recordToAdd += $dataValue.PadLeft($this.rowLayout[$key].width, $this.rowLayout[$key].padWith)
                        }
                    }
                } 
                elseif ($dataValue.Length -gt $this.rowLayout[$key].width) {
                    switch ($this.rowLayout[$key].truncateFromSide) {
                        'left' {
                            $recordToAdd += $dataValue.Substring($dataValue.Length - $this.rowLayout[$key].width)
                        }
                        'right' {
                            $recordToAdd += $dataValue.Substring(0, $this.rowLayout[$key].width)
                        }
                        default {
                            $recordToAdd += $dataValue.Substring(0, $this.rowLayout[$key].width)
                        }
                    }
                } 
                else {
                    $recordToAdd += $dataValue
                }
            }

            $this.recordsToWrite += $recordToAdd
        }

        $returnRecord.added = $addRecord

        if ($this.recordsToWrite.Count -ge $this.flushAfter) {
            $this.writeRecordsToFile($true)
        }

        return $returnRecord
    }

    [void] cleanup() {
        if ($this.recordsToWrite.Count -gt 0) {
            $this.writeRecordsToFile(@{
                    append  = $true
                    newLine = $true
                })
        }
    }

    [void] writeRecordsToFile ([hashtable] $methodParams) {
        $methodParams.append ??= $true
        $methodParams.newLine ??= $true

        if ($methodParams.append -eq $true) {
            if ($methodParams.newLine -eq $true) {
                $this.recordsToWrite | Out-File -FilePath $this.pathAndFilename -Append
            } 
            else {
                $this.recordsToWrite | Out-File -FilePath $this.pathAndFilename -Append -NoNewline
            }
        } 
        else {
            if ($methodParams.newLine -eq $true) {
                $this.recordsToWrite | Out-File -FilePath $this.pathAndFilename
            } 
            else {
                $this.recordsToWrite | Out-File -FilePath $this.pathAndFilename -NoNewline
            }
        }

        $this.recordsToWrite = @()
    }

    [string] convertToString($value) {
        if ([string]::IsNullOrEmpty($value)) {
            return ''
        }

        return [string]$value.ToString().Trim()
    }

    [void] writeGenericError([hashtable] $methodParams) {
        $methodParams.recordID ??= 'N/A'
        $methodParams.errors ??= @()

        Write-Host "$($methodParams.recordID) not added for the following reasons:"
        $methodParams.errors | ForEach-Object {
            Write-Host '---' $_
        }
        Write-Host ''
    }
}


<#
$generator = [fixedWidthRecordsGenerator]::new(@{
    pathAndFilename = 'C:\temp\test.txt'
    rowLayout = [ordered]@{
        'field1' = @{
            width     = 10
            padSide   = 'left'
            padWith   = '0'
            removeFrom = 'left'
            validate  = {
                param($value)
                $ret = @{
                    valid  = $true
                    errors = @()
                }

                if ($value -eq '1234567890') {
                    $ret.valid = $false
                    $ret.errors += 'field1 cannot be 1234567890'
                }

                return $ret
            }
        }
        'field2' = @{
            width     = 10
            padSide   = 'right'
            padWith   = ' '
            removeFrom = 'right'
        }
        'field3' = @{
            width     = 10
            padSide   = 'left'
            padWith   = ' '
            removeFrom = 'right'
        }
    }
})

$generator.addRecord(@{
    field1 = '123'
    field2 = '567890'
    field3 = '890'
})

#cleanup and write any remaining records that were not automatically flushed to disk
$generator.cleanup()
#>