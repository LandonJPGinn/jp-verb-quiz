// word list
// import words from './words.json' assert { type: 'json' };
var words;

$.getJSON("./words.json", function(data) {
  words = data;
})


export default words;