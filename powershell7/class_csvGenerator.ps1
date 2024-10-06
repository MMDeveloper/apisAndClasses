class csvGenerator {
    #full path and filename to write to
    [string] $pathAndFilename = $null

    #array of formatted records to be written
    [array] $recordsToWrite = @()

    #number of records to accumulate before flushing to disk
    [int] $flushAfter = 10

    csvGenerator($methodParams) {
        if ($null -eq $methodParams.pathAndFilename) {
            throw 'pathAndFilename is required'
        }

        $this.pathAndFilename = $methodParams.pathAndFilename
    }

    [object] addRecord([PSCustomObject] $record) {
        $addRecord = $true

        $returnRecord = @{
            added  = $addRecord
            errors = @()
        }

        #if all validations pass, add the record
        if ($addRecord -eq $true) {
            $this.recordsToWrite += $record
        }

        $returnRecord.added = $addRecord

        if ($this.recordsToWrite.Count -ge $this.flushAfter) {
            $this.writeRecordsToFile(@{
                    append = $true
                })
        }

        return $returnRecord
    }

    [void] cleanup() {
        if ($this.recordsToWrite.Count -gt 0) {
            $this.writeRecordsToFile(@{
                    append = $true
                })
        }
    }

    [void] writeRecordsToFile ([hashtable] $methodParams) {
        $methodParams.append ??= $true

        if ($methodParams.append -eq $true) {
            $this.recordsToWrite | Export-Csv -LiteralPath $this.pathAndFilename -Append
        } 
        else {
            $this.recordsToWrite | Export-Csv -LiteralPath $this.pathAndFilename
        }

        $this.recordsToWrite = @()
    }
}


<#
$csvGenerator = [csvGenerator]::new(@{
    pathAndFilename = 'A:\temp\test.txt'
})

$csvGenerator.addRecord([PSCustomObject][ordered]@{
    field1 = '123'
    field2 = '567890'
    field3 = '890'
})

#cleanup and write any remaining records that were not automatically flushed to disk
$csvGenerator.cleanup()
#>