# GeneSync Web Demo

Static browser demo for classmates who cannot run the iOS app.

## Local Preview

```sh
cd web-demo
python3 -m http.server 5173
```

Open `http://localhost:5173`.

## Deploy To Vercel

From this folder:

```sh
vercel
vercel --prod
```

Or import the repository in Vercel and set the project root to `web-demo`.
