enum Gender {
  man('man', 'Man'),
  woman('woman', 'Woman'),
  bisexual('bisexual', 'Bisexual'),
  lesbian('lesbian', 'Lesbian'),
  gay('gay', 'Gay');

  final String value;
  final String label;
  const Gender(this.value, this.label);
}

enum DatingIntention {
  lifePartner('lifePartner', 'Life partner'),
  longTerm('longTerm', 'Long-term relationship'),
  longTermOpenShort('longTermOpenShort', 'Long-term relationship, open to short'),
  shortTermOpenLong('shortTermOpenLong', 'Short-term relationship, open to long'),
  shortTerm('shortTerm', 'Short-term relationship'),
  figuringOut('figuringOut', 'Figuring out my dating goals');

  final String value;
  final String label;
  const DatingIntention(this.value, this.label);
}

enum Religion {
  agnostic('agnostic', 'Agnostic'),
  atheist('atheist', 'Atheist'),
  buddhist('buddhist', 'Buddhist'),
  christian('christian', 'Christian'),
  hindu('hindu', 'Hindu'),
  jain('jain', 'Jain'),
  jewish('jewish', 'Jewish'),
  muslim('muslim', 'Muslim'),
  zoroastrian('zoroastrian', 'Zoroastrian'),
  sikh('sikh', 'Sikh'),
  spiritual('spiritual', 'Spiritual');

  final String value;
  final String label;
  const Religion(this.value, this.label);
}

enum DrinkingSmokingHabits {
  yes('yes', 'Yes'),
  sometimes('sometimes', 'Sometimes'),
  no('no', 'No');

  final String value;
  final String label;
  const DrinkingSmokingHabits(this.value, this.label);
}

enum PromptCategory {
  storyTime('storyTime', 'Story time'),
  myType('myType', 'My type'),
  gettingPersonal('gettingPersonal', 'Getting personal'),
  dateVibes('dateVibes', 'Date vibes');

  final String value;
  final String label;
  const PromptCategory(this.value, this.label);

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
  twoTruthsAndALie('twoTruthsAndALie', 'Two truths and a lie'),
  worstIdea('worstIdea', 'Worst idea I\'ve ever had'),
  biggestRisk('biggestRisk', 'Biggest risk I\'ve taken'),
  biggestDateFail('biggestDateFail', 'My biggest date fail'),
  neverHaveIEver('neverHaveIEver', 'Never have I ever'),
  bestTravelStory('bestTravelStory', 'Best travel story'),
  weirdestGift('weirdestGift', 'Weirdest gift I\'ve given or received'),
  mostSpontaneous('mostSpontaneous', 'Most spontaneous thing I\'ve done'),
  oneThingNeverDoAgain('oneThingNeverDoAgain', 'One thing I\'ll never do again'),
  nonNegotiable('nonNegotiable', 'Something that\'s non-negotiable for me is'),
  hallmarkOfGoodRelationship('hallmarkOfGoodRelationship', 'The hallmark of a good relationship is'),
  lookingFor('lookingFor', 'I\'m looking for'),
  weirdlyAttractedTo('weirdlyAttractedTo', 'I\'m weirdly attracted to'),
  allIAskIsThatYou('allIAskIsThatYou', 'All I ask is that you'),
  wellGetAlongIf('wellGetAlongIf', 'We\'ll get along if'),
  wantSomeoneWho('wantSomeoneWho', 'I want someone who'),
  greenFlags('greenFlags', 'Green flags I look out for'),
  sameTypeOfWeird('sameTypeOfWeird', 'We\'re the same type of weird if'),
  fallForYouIf('fallForYouIf', 'I\'d fall for you if'),
  bragAboutYou('bragAboutYou', 'I\'ll brag about you to my friends if'),
  oneThingYouShouldKnow('oneThingYouShouldKnow', 'The one thing you should know about me is'),
  loveLanguage('loveLanguage', 'My Love Language is'),
  dorkiestThing('dorkiestThing', 'The dorkiest thing about me is'),
  dontHateMeIf('dontHateMeIf', 'Don\'t hate me if I'),
  geekOutOn('geekOutOn', 'I geek out on'),
  ifLovingThisIsWrong('ifLovingThisIsWrong', 'If loving this is wrong, I don\'t want to be right'),
  keyToMyHeart('keyToMyHeart', 'The key to my heart is'),
  wontShutUpAbout('wontShutUpAbout', 'I won\'t shut up about'),
  shouldNotGoOutWithMeIf('shouldNotGoOutWithMeIf', 'You should *not* go out with me if'),
  whatIfIToldYouThat('whatIfIToldYouThat', 'What if I told you that'),
  togetherWeCould('togetherWeCould', 'Together, we could'),
  firstRoundIsOnMeIf('firstRoundIsOnMeIf', 'First round is on me if'),
  whatIOderForTheTable('whatIOderForTheTable', 'What I order for the table'),
  bestSpotInTown('bestSpotInTown', 'I know the best spot in town for'),
  bestWayToAskMeOut('bestWayToAskMeOut', 'The best way to ask me out is by');

  final String value;
  final String label;
  const PromptType(this.value, this.label);

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
  canWeTalkAbout('canWeTalkAbout', 'Can we talk about?'),
  captionThisPhoto('captionThisPhoto', 'Caption this photo'),
  caughtInTheAct('caughtInTheAct', 'Caught in the act'),
  changeMyMindAbout('changeMyMindAbout', 'Change my mind about'),
  chooseOurFirstDate('chooseOurFirstDate', 'Choose our first date'),
  commentIfYouveBeenHere('commentIfYouveBeenHere', 'Comment if you\'ve been here'),
  cookWithMe('cookWithMe', 'Cook with me'),
  datingMeIsLike('datingMeIsLike', 'Dating me is like'),
  datingMeWillLookLike('datingMeWillLookLike', 'Dating me will look like'),
  doYouAgreeOrDisagreeThat('doYouAgreeOrDisagreeThat', 'Do you agree or disagree that'),
  dontHateMeIfI('dontHateMeIfI', 'Don\'t hate me if I'),
  dontJudgeMe('dontJudgeMe', 'Don\'t judge me'),
  mondaysAmIRight('mondaysAmIRight', 'Mondays... am I right?'),
  aBoundaryOfMineIs('aBoundaryOfMineIs', 'A boundary of mine is'),
  aDailyEssential('aDailyEssential', 'A daily essential'),
  aDreamHomeMustInclude('aDreamHomeMustInclude', 'A dream home must include'),
  aFavouriteMemoryOfMine('aFavouriteMemoryOfMine', 'A favourite memory of mine'),
  aFriendsReviewOfMe('aFriendsReviewOfMe', 'A friend\'s review of me'),
  aLifeGoalOfMine('aLifeGoalOfMine', 'A life goal of mine'),
  aQuickRantAbout('aQuickRantAbout', 'A quick rant about'),
  aRandomFactILoveIs('aRandomFactILoveIs', 'A random fact I love is'),
  aSpecialTalentOfMine('aSpecialTalentOfMine', 'A special talent of mine'),
  aThoughtIRecentlyHadInTheShower('aThoughtIRecentlyHadInTheShower', 'A thought I recently had in the shower'),
  allIAskIsThatYou('allIAskIsThatYou', 'All I ask is that you'),
  guessWhereThisPhotoWasTaken('guessWhereThisPhotoWasTaken', 'Guess where this photo was taken'),
  helpMeIdentifyThisPhotoBomber('helpMeIdentifyThisPhotoBomber', 'Help me identify this photo bomber'),
  hiFromMeAndMyPet('hiFromMeAndMyPet', 'Hi from me and my pet'),
  howIFightTheSundayScaries('howIFightTheSundayScaries', 'How I fight the Sunday scaries'),
  howHistoryWillRememberMe('howHistoryWillRememberMe', 'How history will remember me'),
  howMyFriendsSeeMe('howMyFriendsSeeMe', 'How my friends see me'),
  howToPronounceMyName('howToPronounceMyName', 'How to pronounce my name'),
  iBeatMyBluesBy('iBeatMyBluesBy', 'I beat my blues by'),
  iBetYouCant('iBetYouCant', 'I bet you can\'t'),
  iCanTeachYouHowTo('iCanTeachYouHowTo', 'I can teach you how to'),
  iFeelFamousWhen('iFeelFamousWhen', 'I feel famous when'),
  iFeelMostSupportedWhen('iFeelMostSupportedWhen', 'I feel most supported when');

  final String value;
  final String label;
  const AudioPrompt(this.value, this.label);
}
