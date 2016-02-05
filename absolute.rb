#!/usr/bin/ruby -w

def toAbsolute(options)
  # need to add description, allowing for the fact that we TIDY UP THE PATH AS WELL AS ABSOLUTISING IT, WHETHER THE GIVEN PATH IS RELATIVE OR ABSOLUTE
  relativeDirName = options[:relativeDirName]
  currentDir = options[:currentDir]

  if (relativeDirName[0].chomp == '/') then
    currentDir = ''
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
  returnDirName.gsub!(/\/$/,'')
  return returnDirName
end

puts toAbsolute(:relativeDirName => ARGV[0].chomp,:currentDir => ARGV[1].chomp)
