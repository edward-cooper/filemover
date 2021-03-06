#!/usr/bin/ruby -w

# TO DO LIST:
# - make sure Prompt class doesn't use serial numbers or ordinary names to interface with Directory class. Prompt class shouldn't know about these at all. It should only use absolute longnames, or possibly relative names.
# - try implementing multiple prompts, with a way of switching between them.
# - make it possible to convert relative paths to absolute paths within Prompt class, before passing this to Directory.
# - fix error handling, especialyl within prompt. Pass the full command+arguments combo to a different method within Prompt (as an array), and handle it there.

require 'logger'
$logger = Logger.new('/home/edward/tmp/fifo1')
$logger.level = Logger::INFO

$filename = 'output5.txt'

$errorstack = Array.new

class Tree
  @@addChildrenByDefault = true
  @finishedInitialize = false
  def initializeP()
    # Do this while we figure out how child-classes and initialize work together
    @flatList = Array.new
    @totalDeletions = 0
  end
  def checkNil
    @flatList.each_index { | x |
      x or ($logger.warn "#{x} is nil")
    }
  end
  def AddNew(someHash)
  # Is passed a hash containing (at least) a name and a parent number.
  # Adds the new element the list of the parent element's children.
  # Returns the newly-created-element number.
    if someHash.is_a?(Hash) and someHash['Name'] then
      currentLength = @flatList.push(someHash).length - 1;
      @flatList[-1]['Children'] = Array.new;
      if (@@addChildrenByDefault and someHash['Parent']) then
        @flatList[someHash['Parent']]['Children'].push (currentLength); 
      end
      if (@finishedInitialize) then
	$logger.debug("Just added the following hash:")
	$logger.debug(@flatList[-1])
	$logger.debug("Current length is #{currentLength}")
      end 
      return currentLength
    else
      return nil
    end
  end
  def deleteRecord(recordNumber)
    # deletes a record. Removes references to that record as child. Moves references to any higher-number record down a level, since this is what happens to the array when we remove an element.
    # For example, if we delete record number 15, then any reference of a parent or child to a record of >15 will be moved down one.
    # Before doing this, we recurse on given record's children (if there are any), in order to do exactly the same for any children of the record.
    # Recursion on children takes place backwards. This is because changes made to lower-numbered records affects (or can affect) higher-numbered records, but not vice-versa.
    $logger.info("Deleting record #{recordNumber}: #{@flatList[recordNumber]}")
    @flatList[recordNumber] and @flatList[recordNumber]['Children'].sort.reverse.each { | x |
    # thinking about it, we want to reverse the elements' values, not the ordering of the elements themselves. Above line may need changing.
      deleteRecord(x.to_i)
    }
    @flatList.delete_at(recordNumber)
    @flatList.each { | x |

      if (x['Parent'].to_i > recordNumber) then
        x['Parent'] -= 1 
      end
      x['Children'].each_index { | y |
	if x['Children'][y] > recordNumber then
	x['Children'][y] -= 1
	elsif x['Children'][y] == recordNumber then
	  # puts "Deleting child record #{recordNumber}"
	  # x['Children'].delete_at(y) # = nil
	  # above: old way of doing it. This screwed up the array's index, since we were looping based on the very thing we were deleting.
	  # below: new way of doing it. Just mark the record as nil, and delete it later.
	  x['Children'][y] = nil 
	end
      }
      x['Children'].delete_if { | z | z == nil }
      # THE LESSON: DON'T MESS WITH ARRAYS' INDICES WITHIN A LOOP BASED ON THAT ARRAY.
    }
   if (@flatList[recordNumber]) then
     parent = @flatList[recordNumber]['Parent']
   # below: seems to be necessary for removing duplicates. Not sure why this is happening.
     @flatList[parent]['Children'].uniq!
   end
  end
  def modRecord(targetRecord,someHash)
  # Is passed a has containing any record details you want. Whatevre is contained in the hash is changed. Whatever is not, is retained.
  # Returns the new record.
  
    someHash.each_key { | k |
      @flatList[targetRecord][k] = someHash[k] 
    }
    return @flatList[targetRecord]
  end
  def getSerialNumber(name, parent)
     # returns parent number of a given tree item (ie returns an INTEGER)
     @flatList.each_index do | current |
       if (@flatList[current]['Name'] == name and @flatList[current]['Parent'] == parent) then
         return current 
       end
     end
     return nil
  end
  def save(fileName)
    # Technically, this should go in Directory class, not in Tree class. Tree class doesn't recognise LongName (though it allows it)
    saveFile = File.new(fileName,'w')
    @flatList.each { | x |
      saveFile.puts x['LongName']
    }
    saveFile.close
  end
  def getChildren(number)
    # returns an array of integers, which contains the record's children's serial numbers
    return @flatList[number]['Children']
  end
  def getDetails(number)
    # returns a hash with the record. Returns nil if element not found (since this is what the array object does).
    return @flatList[number] 
  end
  def tellAll()
    # returns entire table
    @flatList.each_index { | i |
      #logger.warn ("Index number #{i}:")
      #logger.warn (@flatList[i].to_s)
      puts "Result for entry #{i}:"
      puts @flatList[i];
    }
  end
  def doSomethingRecursively(number,action,actionees)
    @flatList[number]['Children'].reverse.each { | x |
      doSomethingRecursively(x,action,{ })
    }
    action.call (number)

  end
end

class EdDirectoryClass < Tree
  def initialize (lines)
    # we always start at ROOT, not at current. [insert note as to why this makes sense]
    initializeP()
    # below: remove current and/or root directory
    lines.delete_if { | x |
      (x.chomp == '.' or x.chomp == '/') 
    }
    # below: add root directory
    AddNew('Name'=>'/','Parent'=>nil,'LongName'=>'/') 
    lines.each { | x | 
      # below: remove current directory prefix
      if (x[0] == '.') then
        x = x[1..-1]
      end
      addDirectory(x.chomp) 
    }
    @finishedInitialize = true  
  end

  def getNumberFromLongName(longName)
    return @flatList.index { | x | x['LongName'] == longName }
  end
    
  def addDirectory(longName)
    namesArray = splitLongName(longName)
    parentNumber = 0 
    namesArray.each_index { | i |
      if (i == 0) then
        parentNumber = 0
      end
      directoryNumber = getSerialNumber(namesArray[i],parentNumber) 
      # BELOW: if the directory is found, then the next loop should search the next directory/file found in the array. Otherwise, the directory should be added. NOTE THAT in either case, we go through the loop again. 
      if (not (directoryNumber ==  nil)) then
        parentNumber = directoryNumber
      else
	longNameToAdd = '/' + namesArray[0..i].join("/")
        parentNumber = AddNew('Name'=>namesArray[i],'Parent'=>parentNumber.to_i,'LongName'=>longNameToAdd)
      end
    }
  end
  def showContents(directory)
    # returns an array containing the NAMES of the children of the current directory
    # the argument 'directory'  must be one of three object types:
    # either a) a hash, which must contain the elements 'Name' and 'Parent'. Name is a string; parent is an integer.
    # or b) an integer, which is the directory-in-question's serial number.
    # or c) a string (called from prompt class), which must be a long directory name.
    if (directory.is_a? Hash) then 
      directoryNumber = getSerialNumber(directory['Name'], directory['Parent'])
    elsif (directory.is_a? String) then
      directoryNumber = @flatList.index { | x | x['LongName'] == directory.chomp }
      if directoryNumber == nil then
	return nil
      end
    else # just assume it's an integer :)
      directoryNumber = directory
    end 
    childrenNames = Array.new
    children = getChildren(directoryNumber)
    children.each { | i |
      childrenNames.push (getDetails(i)['Name'].chomp)
    }
    return childrenNames
  end
  def splitLongName(longName)
    # takes a long name in the format /foo/bar/subdir/..., and returns an array with the same strings in it.
    # For an unknown reason, the first element in this is always empty, so we remove the first element beore returning.
    return longName.split("/")[1..-1]
  end
  def getLongName(number)
    if (number == 0)
      return ''
    else
      return getLongName(@flatList[number]['Parent'].to_i).to_s + '/' + @flatList[number]['Name']
    end
    
  end
  def getParent (directory)
    # takes a string, which is the directory's longname. Returns a string, which is the directory's parent's longname.
    # returns nil if fails, and writes an error to the logfile.
    # ACTION above
    directoryNumber = @flatList.index {| x | x['LongName'] = directory.chomp }
    directoryNumber == nil and ( return nil )
    return @flatList[directoryNumber]['LongName'].chomp 
  end
  def copy(currentDirName,targetDirName)
    results = Array.new
    number = @flatList.index { | x | x['LongName'] == currentDirName.chomp }
    # below: check we can find the source directory, and kick up an error if we can't find it.
    if (number == nil) then 
      $errorstack.push ("Can't find #{currentDirName}")
      return nil
    end
    existingParentNumber = @flatList[number]['Parent'].to_i;
    existingParentLongName = @flatList[existingParentNumber]['LongName'];

    # below: check new directory exists. Should be its own function as it's a duplicate with moveACTION
    targetDirNumber = @flatList.index { | x | x["LongName"].chomp == targetDirName }
    # below: add the target directory if it doesn't exist.
    if (targetDirNumber == nil) then
      addDirectory(targetDirName)
      targetDirNumber = @flatList.index { | x | x == targetDirName }
    end
    getNewName = lambda { | copyeeNumber, targetDirNameX |
      @flatList[copyeeNumber]['Children'].each { | x |
        getNewName.call(x,targetDirNameX)
      } 
      existingCopyeeLongName = @flatList[copyeeNumber]['LongName'] 
      if (targetDirNameX[-1] != '/') then
        targetDirNameX = targetDirNameX + '/'
      end

      newCopyeeLongName = existingCopyeeLongName.sub(/#{existingParentLongName}/,targetDirNameX)
      # below: replace any double forward-slashes with single forward-slashes
      newCopyeeLongName.gsub!(/\/\//,'/'); 
      $logger.info("Just replaced #{existingCopyeeLongName} with #{newCopyeeLongName}")
      results.push(newCopyeeLongName)
    }
    getNewName.call(number,targetDirName)
    results.each { | x | addDirectory(x) }
    
  end
  def move(oldDirName,targetDirName)
    # takes a serial number and a long directory name (string) as arguments. Returns nil if targetDirName not found (ie target directory doesn't exist); otherwise, doesn't return aynthing (at the moment).
    
    number = @flatList.index { | x | x['LongName'] == oldDirName }
    oldParent = @flatList[number]['Parent']

    #below: check new directory exists, otherwise return nil
    targetDirNumber = @flatList.index { | x | x["LongName"].chomp == targetDirName } 
    if (targetDirNumber == nil) then
      return nil
    end
    newLongName = targetDirName + '/' + @flatList[number]['Name']
    modRecord(number, {"Parent"=> targetDirNumber,'LongName'=>newLongName})
    # above: modify the record itself.
    # below: modify the record's parent to add it as a child
    @flatList[targetDirNumber]['Children'].push(number)
    #below: remove the old parent's child record
    @flatList[oldParent]['Children'].delete(number)
    # HERE NEEDS MORE WORK 
    setLongName = lambda { | x |
      @flatList[x]['LongName'] = getLongName(x)
    }
    doSomethingRecursively(number,setLongName, { })
    ##@flatList[number]['LongName'] = getLongName(number)
    #@flatList[number]['Children'].each { | x |
      #@flatList[x]['LongName'] = getLongName(x)
    #}
  end
  def describe(number)
    if(@flatList[number]) then
      $logger.info("Record of number #{number}")
      $logger.info(@flatList[number])
    else
      $logger.info("No record of record number #{number}")
    end
  end
end

class EdPromptClass
  @@promptText = '> '
  
  def initialize(targetTree)
    if (not( targetTree.is_a? EdDirectoryClass)) then
      exit
    else
      @targetTree = targetTree 
      @currentDirectory = '/' 
    end
  end

  def menuChoice(promptInput)
    promptInput = promptInput.chomp
    $logger.debug("Recorded command #{promptInput}")
    promptWords = promptInput.split(" ")
    # currentDirName = getCurrentDirDetails['Name']

    if (promptWords[0] == 'ls') then
      promptWords[1] ? showDirectory = toAbsolute(:relativeDirName => promptWords[1]) : showDirectory = @currentDirectory
      # above: show current directory if none is specified. Otherwise, show the specified one, after it's absolutised.

      @targetTree.getNumberFromLongName(showDirectory) or lambda { 
	puts "#{showDirectory} not found. Showing current.".upcase
        showDirectory = @currentDirectory
      }.call 
      # above: if directory doesn't exist in the tree, just show current.

      puts "Contents of #{showDirectory}"
      contents = @targetTree.showContents(showDirectory) 
      puts contents 

    elsif (promptWords[0] == 'cd') then
      oldDirectory = @currentDirectory
      @currentDirectory = toAbsolute(:relativeDirName => promptWords[1])
      if (not @targetTree.getNumberFromLongName(@currentDirectory)) then
	puts "DIRECTORY #{@currentDirectory} NOT FOUND"
        @currentDirectory = oldDirectory
      end
      # currentDirName = getCurrentDirDetails['LongName']
      puts "Current directory is #{@currentDirectory}"

    elsif (promptWords[0] == 'exit' or promptWords[0] == 'quit') then
      puts "Quitting."
      $logger.info("QUIT-----------------------------------------------")
      exit
    
    elsif (promptWords[0] == 'del') then
      dirName = toAbsolute(:relativeDirName => promptWords[1])
      puts dirName
      @targetTree.deleteRecord(@targetTree.getNumberFromLongName(dirName))
       
    elsif (promptWords[0] == 'describe') then
      @targetTree.describe(promptWords[1].chomp.to_i)

    elsif (promptWords[0] == 'cp') then
      fileA = toAbsolute(:relativeDirName => promptWords[1])
      fileB = toAbsolute(:relativeDirName => promptWords[2])
      # HERE
      result = @targetTree.copy(fileA, fileB)
      (not result) and puts $errorstack 

    elsif (promptWords[0] == 'mv') then
      fileA = toAbsolute(:relativeDirName => promptWords[1])
      fileB = toAbsolute(:relativeDirName => promptWords[2])
      result = @targetTree.move(fileA,fileB)
      if (not result) then
        puts "FAILED"
      end

    elsif (promptWords[0] == 'mkdir' or promptWords[0] == 'touch') then
      newName = toAbsolute(:relativeDirName => promptWords[1].to_s)
      @targetTree.addDirectory(newName)
      #puts "Added directory #{newName}"

    elsif (promptWords[0] == 'save')
      @targetTree.save(promptWords[1])

    else
      puts "Command not recognised."

    end

  end
  def getCurrentDirDetails()
     puts "THIS SHOULD NO LONGER BE CALLED."
     exit
  end
  def toAbsolute(options)
    # need to add description, allowing for the fact that we TIDY UP THE PATH AS WELL AS ABSOLUTISING IT, WHETHER THE GIVEN PATH IS RELATIVE OR ABSOLUTE
    relativeDirName = options[:relativeDirName]
     
    if (relativeDirName[0].chomp == '/') then
      currentDir = ''
    else
      currentDir = @currentDirectory
    end
    # above: if path is already absolute then ignore the current directory, but tidy it up.

    nameList = Array.new
    nameList = relativeDirName.chomp.split('/')
    nameList.delete('.')
    # above: remove any refrences to current directory

    if (nameList.index('..')) then
      # if we detect a parent directory in the mix, things get more complicated. 
      newDirList = Array.new
      newDirList = currentDir.chomp.split('/')
      nameList.each { | x |
	if ( x == '..' ) then
	  newDirList.pop
	else
	  newDirList.push(x.chomp)
	end
      }
      returnDirName = '/' + newDirList.join('/')
    else
      returnDirName = currentDir + '/' + nameList.join('/') 
    end
    returnDirName.gsub!(/\/\//,'/') 
    (returnDirName.length < 1) and returnDirName.gsub!(/\/$/,'')
    return returnDirName
  end

end


$logger.info("\n\n")
$logger.info("STARTED--------------------------------")
inputFile = File.new($filename,'r')
dirTree = EdDirectoryClass.new(inputFile.readlines)
inputFile.close
dirTree.tellAll
edPrompt = EdPromptClass.new(dirTree)
dirTree.checkNil
while (true) do 
  print "> "
  edPrompt.menuChoice(gets.chomp)
  puts
#  dirTree.tellAll
end 
# moved files/dirs have incorrect longnames. Need to fix this.
# and copy function, where we just addDirectory(newName), and do the same for all the subdirectories


