module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    './app/components/**/*.rb'
  ],
  safelist: [
    'w-4', 'w-5', 'w-6',
    'h-4', 'h-5', 'h-6'
  ]
}