{-# LANGUAGE OverloadedStrings #-}

import Control.Applicative (empty)
import Data.List (intersperse)
import Data.Monoid ((<>))
import Hakyll
    ( Context(..), Item(..), Configuration(..)
    , Rules, Pattern, Compiler, Identifier
    , defaultContext
    , dateField
    , tagsFieldWith
    , constField
    , listField
    , loadAll
    , loadAndApplyTemplate
    , applyAsTemplate
    , templateCompiler
    , copyFileCompiler
    , match
    , compile
    , getResourceBody
    , relativizeUrls
    , route
    , idRoute
    , recentFirst
    , create
    , makeItem
    , setExtension
    , fromGlob
    , fromCapture
    , pandocCompilerWith
    , hakyllWith
    , defaultHakyllReaderOptions
    , defaultHakyllWriterOptions
    , defaultConfiguration
    , toUrl
    )
import Hakyll.Web.Tags (Tags, buildTags, tagsRules, getTags)
import Text.Pandoc.Options
    (ReaderOptions(..), WriterOptions(..), HTMLMathMethod(..))
import Text.Blaze.Html ((!), toHtml, toValue)
import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A

pandocReaderOptions :: ReaderOptions
pandocReaderOptions = defaultHakyllReaderOptions

pandocWriterOptions :: WriterOptions
pandocWriterOptions =
    defaultHakyllWriterOptions
        { writerHTMLMathMethod = MathJax ""
        }

pandoc :: Compiler (Item String)
pandoc = pandocCompilerWith pandocReaderOptions pandocWriterOptions

static :: Pattern -> Rules ()
static f = match f $ do
    route idRoute
    compile copyFileCompiler

directory :: (Pattern -> Rules a) -> String -> Rules a
directory act f = act $ fromGlob $ f ++ "/**"

config :: Configuration
config =
    defaultConfiguration
        { providerDirectory = "CampHog"
        }

main :: IO ()
main = hakyllWith config $ do
    -- SEE: http://vapaus.org/text/hakyll-configuration.html
    mapM_ (directory static) ["css", "font", "js", "images"]

    match "*.md" $ do
        route $ setExtension "html"
        compile $ pandoc
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    -- SEE: http://javran.github.io/posts/2014-03-01-add-tags-to-your-hakyll-blog.html
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    match "posts/*" $ do
        route $ setExtension "html"
        compile $ do
            -- SEE: https://github.com/robwhitaker/hakyll-portfolio-blog/blob/729f2d51a1ff0d4f63e6a5cf4fc1b42cd6468d0b/site.hs#L146
            let ctx = tagsFieldNonEmpty "tags" tags <> postCtx

            pandoc
                >>= loadAndApplyTemplate "templates/post.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    tagsRules tags $ \tag pattern -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            posts <- loadAll pattern >>= recentFirst

            let ctx =
                    constField "title" title
                    <> listField "posts" postCtx (return posts)
                    <> defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    create ["archive.html"] $ do
        route idRoute
        compile $ do
            posts <- loadAll "posts/*" >>= recentFirst

            let ctx =
                    listField "posts" postCtx (return posts)
                    <> constField "title" "Archives"
                    <> defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- loadAll "posts/*" >>= recentFirst

            let ctx =
                    listField "posts" postCtx (return posts)
                    <> constField "title" ""
                    <> defaultContext

            getResourceBody
                >>= applyAsTemplate ctx
                >>= loadAndApplyTemplate "templates/default.html" postCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

postCtx :: Context String
postCtx = dateField "date" "%Y-%m-%d" <> defaultContext

tagsFieldNonEmpty :: String -> Tags -> Context a
tagsFieldNonEmpty =
    tagsFieldWith getTagsNonEmpty simpleRenderLink (mconcat . intersperse " ")
    where
        getTagsNonEmpty :: Identifier -> Compiler [String]
        getTagsNonEmpty identifier = do
            tags <- getTags identifier
            if null tags then empty else return tags

        simpleRenderLink :: String -> (Maybe FilePath) -> Maybe H.Html
        simpleRenderLink _ Nothing = Nothing
        simpleRenderLink tag (Just filePath) =
            Just
            $ H.a
                ! A.class_ "badge badge-light"
                ! A.href (toValue $ toUrl filePath)
            $ toHtml (tag)
