enum Gender {
  man('Man'),
  woman('Woman'),
  bisexual('Bisexual'),
  lesbian('Lesbian'),
  gay('Gay');

  final String label;
  const Gender(this.label);
}

enum DatingIntention {
  lifePartner('Life partner'),
  longTerm('Long-term relationship'),
  longTermOpenShort('Long-term relationship, open to short'),
  shortTermOpenLong('Short-term relationship, open to long'),
  shortTerm('Short-term relationship'),
  figuringOut('Figuring out my dating goals');

  final String label;
  const DatingIntention(this.label);
}

enum Religion {
  agnostic('Agnostic'),
  atheist('Atheist'),
  buddhist('Buddhist'),
  christian('Christian'),
  hindu('Hindu'),
  jain('Jain'),
  jewish('Jewish'),
  muslim('Muslim'),
  zoroastrian('Zoroastrian'),
  sikh('Sikh'),
  spiritual('Spiritual');

  final String label;
  const Religion(this.label);
}

enum DrinkingSmokingHabits {
  yes('Yes'),
  sometimes('Sometimes'),
  no('No');

  final String label;
  const DrinkingSmokingHabits(this.label);
}

enum PromptCategory {
  storyTime('Story time'),
  myType('My type'),
  gettingPersonal('Getting personal'),
  dateVibes('Date vibes');

  final String label;
  const PromptCategory(this.label);

  List<PromptType> getPrompts() {
    switch (this) {
      case PromptCategory.storyTime:
        return [
          PromptType.twoTruthsAndALie,
          PromptType.worstIdea,
          PromptType.biggestRisk,
          PromptType.biggestDateFail,
          PromptType.neverHaveIEver,
          PromptType.bestTravelStory,
          PromptType.weirdestGift,
          PromptType.mostSpontaneous,
          PromptType.oneThingNeverDoAgain,
        ];
      case PromptCategory.myType:
        return [
          PromptType.nonNegotiable,
          PromptType.hallmarkOfGoodRelationship,
          PromptType.lookingFor,
          PromptType.weirdlyAttractedTo,
          PromptType.allIAskIsThatYou,
          PromptType.wellGetAlongIf,
          PromptType.wantSomeoneWho,
          PromptType.greenFlags,
          PromptType.sameTypeOfWeird,
          PromptType.fallForYouIf,
          PromptType.bragAboutYou,
        ];
      case PromptCategory.gettingPersonal:
        return [
          PromptType.oneThingYouShouldKnow,
          PromptType.loveLanguage,
          PromptType.dorkiestThing,
          PromptType.dontHateMeIf,
          PromptType.geekOutOn,
          PromptType.ifLovingThisIsWrong,
          PromptType.keyToMyHeart,
          PromptType.wontShutUpAbout,
          PromptType.shouldNotGoOutWithMeIf,
          PromptType.whatIfIToldYouThat,
        ];
      case PromptCategory.dateVibes:
        return [
          PromptType.togetherWeCould,
          PromptType.firstRoundIsOnMeIf,
          PromptType.whatIOderForTheTable,
          PromptType.bestSpotInTown,
          PromptType.bestWayToAskMeOut,
        ];
    }
  }
}

enum PromptType {
  twoTruthsAndALie('Two truths and a lie'),
  worstIdea('Worst idea I\'ve ever had'),
  biggestRisk('Biggest risk I\'ve taken'),
  biggestDateFail('My biggest date fail'),
  neverHaveIEver('Never have I ever'),
  bestTravelStory('Best travel story'),
  weirdestGift('Weirdest gift I\'ve given or received'),
  mostSpontaneous('Most spontaneous thing I\'ve done'),
  oneThingNeverDoAgain('One thing I\'ll never do again'),
  nonNegotiable('Something that\'s non-negotiable for me is'),
  hallmarkOfGoodRelationship('The hallmark of a good relationship is'),
  lookingFor('I\'m looking for'),
  weirdlyAttractedTo('I\'m weirdly attracted to'),
  allIAskIsThatYou('All I ask is that you'),
  wellGetAlongIf('We\'ll get along if'),
  wantSomeoneWho('I want someone who'),
  greenFlags('Green flags I look out for'),
  sameTypeOfWeird('We\'re the same type of weird if'),
  fallForYouIf('I\'d fall for you if'),
  bragAboutYou('I\'ll brag about you to my friends if'),
  oneThingYouShouldKnow('The one thing you should know about me is'),
  loveLanguage('My Love Language is'),
  dorkiestThing('The dorkiest thing about me is'),
  dontHateMeIf('Don\'t hate me if I'),
  geekOutOn('I geek out on'),
  ifLovingThisIsWrong('If loving this is wrong, I don\'t want to be right'),
  keyToMyHeart('The key to my heart is'),
  wontShutUpAbout('I won\'t shut up about'),
  shouldNotGoOutWithMeIf('You should *not* go out with me if'),
  whatIfIToldYouThat('What if I told you that'),
  togetherWeCould('Together, we could'),
  firstRoundIsOnMeIf('First round is on me if'),
  whatIOderForTheTable('What I order for the table'),
  bestSpotInTown('I know the best spot in town for'),
  bestWayToAskMeOut('The best way to ask me out is by');

  final String label;
  const PromptType(this.label);

  PromptCategory getCategory() {
    for (var category in PromptCategory.values) {
      if (category.getPrompts().contains(this)) {
        return category;
      }
    }
    return PromptCategory.storyTime; // Default category if not found
  }
}

enum AudioPrompt {
  canWeTalkAbout('Can we talk about?'),
  captionThisPhoto('Caption this photo'),
  caughtInTheAct('Caught in the act'),
  changeMyMindAbout('Change my mind about'),
  chooseOurFirstDate('Choose our first date'),
  commentIfYouveBeenHere('Comment if you\'ve been here'),
  cookWithMe('Cook with me'),
  datingMeIsLike('Dating me is like'),
  datingMeWillLookLike('Dating me will look like'),
  doYouAgreeOrDisagreeThat('Do you agree or disagree that'),
  dontHateMeIfI('Don\'t hate me if I'),
  dontJudgeMe('Don\'t judge me'),
  mondaysAmIRight('MondaysAmIRight?'),
  aBoundaryOfMineIs('A boundary of mine is'),
  aDailyEssential('A daily essential'),
  aDreamHomeMustInclude('A dream home must include'),
  aFavouriteMemoryOfMine('A favourite memory of mine'),
  aFriendsReviewOfMe('A friend\'s review of me'),
  aLifeGoalOfMine('A life goal of mine'),
  aQuickRantAbout('A quick rant about'),
  aRandomFactILoveIs('A random fact I love is'),
  aSpecialTalentOfMine('A special talent of mine'),
  aThoughtIRecentlyHadInTheShower('A thought I recently had in the shower'),
  allIAskIsThatYou('All I ask is that you'),
  guessWhereThisPhotoWasTaken('Guess where this photo was taken'),
  helpMeIdentifyThisPhotoBomber('Help me identify this photo bomber'),
  hiFromMeAndMyPet('Hi from me and my pet'),
  howIFightTheSundayScaries('How I fight the Sunday scaries'),
  howHistoryWillRememberMe('How history will remember me'),
  howMyFriendsSeeMe('How my friends see me'),
  howToPronounceMyName('How to pronounce my name'),
  iBeatMyBluesBy('I beat my blues by'),
  iBetYouCant('I bet you can\'t'),
  iCanTeachYouHowTo('I can teach you how to'),
  iFeelFamousWhen('I feel famous when'),
  iFeelMostSupportedWhen('I feel most supported when');

  final String label;
  const AudioPrompt(this.label);
}
