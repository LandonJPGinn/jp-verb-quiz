import React, { useState, useEffect } from 'react';

const FlashcardQuiz = () => {
  const [words, setWords] = useState([]);
  const [currentWord, setCurrentWord] = useState(null);
  const [userAnswer, setUserAnswer] = useState('');
  const [feedback, setFeedback] = useState('');

  useEffect(() => {
    // Load words from JSON file
    fetch('/path/to/words.json')
      .then(response => response.json())
      .then(data => setWords(data))
      .catch(error => console.error('Error loading words:', error));
  }, []);

  const getRandomWord = () => {
    const randomIndex = Math.floor(Math.random() * words.length);
    return words[randomIndex];
  };

  const handleNextWord = () => {
    const newWord = getRandomWord();
    setCurrentWord(newWord);
    setUserAnswer('');
    setFeedback('');
  };

  const handleSubmitAnswer = () => {
    if (userAnswer.trim().toLowerCase() === currentWord.translation.toLowerCase()) {
      setFeedback('Correct!');
    } else {
      setFeedback(`Incorrect. The correct translation is: ${currentWord.translation}`);
    }
  };

  return (
    <div>
      <h1>Flashcard Quiz</h1>
      {currentWord ? (
        <div>
          <h2>{currentWord.word}</h2>
          <input 
            type="text" 
            value={userAnswer} 
            onChange={(e) => setUserAnswer(e.target.value)} 
          />
          <button onClick={handleSubmitAnswer}>Submit</button>
          <p>{feedback}</p>
          <button onClick={handleNextWord}>Next Word</button>
        </div>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
};

export default FlashcardQuiz;
