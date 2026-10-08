/* Trip info for the Recursos tab. Edit only this file; app updates never overwrite it.
   Leave "sections" empty and the Trip info card is hidden.

   Each section has a title and a list of items. An item is:
     { label: "Hotel", text: "Hotel Plaza, Calle 10 #5-20\nCheck-in after 3 pm", url: "https://...", linkText: "Open in Maps" }
   Only "label" is required. "url" may start with https:, tel: or mailto:. "\n" makes a new line.

   Example:
   window.RUMBO_TRIP = {
     sections: [
       { title: "Flights", items: [
         { label: "Out: Fri Nov 14", text: "DTW to BOG, departs 6:05 am" },
         { label: "Back: Tue Nov 18", text: "BOG to DTW, departs 11:40 am" } ] },
       { title: "Where we are staying", items: [
         { label: "Casa Medellín", text: "Calle 10 #5-20", url: "https://maps.google.com/?q=Casa+Medellin", linkText: "Open in Maps" } ] }
     ]
   };
*/
window.RUMBO_TRIP = {
  sections: []
};
