compile abstract instructions
scanMethod
	"Scan the method (and all embedded blocks) to determine
		- what the last bytecode is; extra bytes at the end of a method are used to encode things like source pointers or temp names
		- if the method needs a frame or not
		- what are the targets of any backward branches.
		- how many blocks it creates
		- how many counters it needs/conditional branches it contains
	 Answer the block count or on error a negative error code"
	| latestContinuation nExts descriptor pc numBlocks distance targetPC framelessStackDelta |
	<var: #descriptor type: #'BytecodeDescriptor *'>
	needsFrame := false.
	inBlock := false.
	prevBCDescriptor := nil.
	numCounters := 0.
	self cppIf: #NewspeakVM ifTrue:
		[numIRCs := 0].
	(primitiveIndex > 0
	 and: [coInterpreter isQuickPrimitiveIndex: primitiveIndex]) ifTrue:
		[^0].
	pc := latestContinuation := initialPC.
	numBlocks := framelessStackDelta := nExts := 0.
	[pc <= endPC] whileTrue:
		[byte0 := (objectMemory fetchByte: pc ofObject: methodObj) + bytecodeSetOffset.
		descriptor := self generatorAt: byte0.
		(descriptor isReturn
		 and: [pc >= latestContinuation]) ifTrue:
			[endPC := pc].
		 needsFrame ifFalse:
			[(descriptor needsFrameFunction isNil
			  or: [self perform: descriptor needsFrameFunction with: framelessStackDelta])
				ifTrue: [needsFrame := true]
				ifFalse: [framelessStackDelta := framelessStackDelta + descriptor stackDelta]].
		descriptor isBranch ifTrue:
			[distance := self spanFor: descriptor at: pc exts: nExts in: methodObj.
			 targetPC := pc + descriptor numBytes + distance.
			 (self isBackwardBranch: descriptor at: pc exts: nExts in: methodObj)
				ifTrue: [self initializeFixupAt: targetPC - initialPC]
				ifFalse:
					[latestContinuation := latestContinuation max: targetPC.
					 (descriptor isBranchTrue or: [descriptor isBranchFalse]) ifTrue:
						[numCounters := numCounters + 1]]].
		descriptor isBlockCreation ifTrue:
			[numBlocks := numBlocks + 1.
			 distance := self spanFor: descriptor at: pc exts: nExts in: methodObj.
			 targetPC := pc + descriptor numBytes + distance.
			 latestContinuation := latestContinuation max: targetPC].
		self cppIf: #NewspeakVM ifTrue:
			[descriptor hasIRC ifTrue:
				[numIRCs := numIRCs + 1]].
		pc := pc + descriptor numBytes.
		nExts := descriptor isExtension ifTrue: [nExts + 1] ifFalse: [0].
		prevBCDescriptor := descriptor].
	^numBlocks