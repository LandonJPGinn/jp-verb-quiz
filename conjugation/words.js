// word list
// import words from './words.json' assert { type: 'json' };
let words;

fetch('./words.json')
  .then(response => response.json())
  .then(data => {
    // Check if the imported JSON object has the expected type property
    if (data && typeof data === 'object') {
        // Proceed with your code
        words = data;
    } else {
        console.error('The imported JSON file does not have the expected type property.');
    }
  })
  .catch(error => console.error('Error fetching JSON:', error));




export default words;