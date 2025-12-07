"""
title: Gemini Manifold Pipe
author: justinh-rahb, matthewh
author_url: https://github.com/justinh-rahb
funding_url: https://github.com/open-webui
version: 0.1.6
license: MIT

Fork of https://openwebui.com/f/justinrahb/google_genai that conceals thoughts in a collapsible UI element.
"""

import os
import re
import asyncio
import time
from pydantic import BaseModel, Field
import google.generativeai as genai
from google.generativeai.types import GenerationConfig, GenerateContentResponse
from typing import List, Union, Iterator, Callable, Awaitable
from markdown import Markdown

DEBUG = False


class Pipe:
    class Valves(BaseModel):
        GOOGLE_API_KEY: str = Field(default="")
        USE_PERMISSIVE_SAFETY: bool = Field(default=False)
        THINKING_MODEL_PATTERN: str = Field(default=r"thinking")
        emit_interval: int = Field(
            default=5, description="Interval in seconds between status updates."
        )

    def __init__(self):
        try:
            self.id = "google_genai"
            self.type = "manifold"
            self.name = "Google: "
            self.valves = self.Valves(
                **{
                    "GOOGLE_API_KEY": os.getenv("GOOGLE_API_KEY", ""),
                    "USE_PERMISSIVE_SAFETY": False,
                    "THINKING_MODEL_PATTERN": r"thinking",
                    "emit_interval": 5,  # Default emit interval
                }
            )
            if DEBUG:
                print("[INIT] Initialized Pipe with Valves configuration.")
        except Exception as e:
            if DEBUG:
                print(f"[INIT] Error during initialization: {e}")
        finally:
            if DEBUG:
                print("[INIT] Initialization complete.")

    async def emit_thoughts(
        self, thoughts: str, __event_emitter__: Callable[[dict], Awaitable[None]]
    ) -> None:
        """Emit thoughts in a collapsible element."""
        try:
            if not thoughts.strip():
                if DEBUG:
                    print("[emit_thoughts] No thoughts to emit.")
                return
            enclosure = f"""<details>
<summary>Click to expand thoughts</summary>
{thoughts.strip()}
</details>""".strip()
            if DEBUG:
                print(f"[emit_thoughts] Emitting thoughts: {enclosure}")
            message_event = {
                "type": "message",
                "data": {"content": enclosure},
            }
            await __event_emitter__(message_event)
        except Exception as e:
            if DEBUG:
                print(f"[emit_thoughts] Error emitting thoughts: {e}")
        finally:
            if DEBUG:
                print("[emit_thoughts] Finished emitting thoughts.")

    def is_thinking_model(self, model_id: str) -> bool:
        """Check if the model is a thinking model based on the valve pattern."""
        try:
            result = bool(
                re.search(self.valves.THINKING_MODEL_PATTERN, model_id, re.IGNORECASE)
            )
            if DEBUG:
                print(
                    f"[is_thinking_model] Model ID '{model_id}' is a thinking model: {result}"
                )
            return result
        except Exception as e:
            if DEBUG:
                print(f"[is_thinking_model] Error checking model: {e}")
            return False
        finally:
            if DEBUG:
                print("[is_thinking_model] Completed model check.")

    def get_google_models(self):
        """Retrieve Google models with prefix stripping."""
        try:
            if not self.valves.GOOGLE_API_KEY:
                if DEBUG:
                    print("[get_google_models] GOOGLE_API_KEY is not set.")
                return [
                    {
                        "id": "error",
                        "name": "GOOGLE_API_KEY is not set. Please update the API Key in the valves.",
                    }
                ]
            genai.configure(api_key=self.valves.GOOGLE_API_KEY)
            models = genai.list_models()
            if DEBUG:
                print(
                    f"[get_google_models] Retrieved {len(models)} models from Google."
                )
            return [
                {
                    "id": self.strip_prefix(model.name),
                    "name": model.display_name,
                }
                for model in models
                if "generateContent" in model.supported_generation_methods
                if model.name.startswith("models/")
            ]
        except Exception as e:
            if DEBUG:
                print(f"[get_google_models] Error fetching Google models: {e}")
            return [
                {"id": "error", "name": f"Could not fetch models from Google: {str(e)}"}
            ]
        finally:
            if DEBUG:
                print("[get_google_models] Completed fetching Google models.")

    def strip_prefix(self, model_name: str) -> str:
        """
        Strip known prefixes from the model name.
        Strips 'google_genai.' or 'models/' to preserve the rest of the model_id, including internal dots.
        """
        try:
            if model_name.startswith("google_genai."):
                stripped = model_name[12:]
                if DEBUG:
                    print(f"[strip_prefix] Stripped 'google_genai.': '{stripped}'")
                return stripped
            elif model_name.startswith("models/"):
                stripped = model_name[7:]
                if DEBUG:
                    print(f"[strip_prefix] Stripped 'models/': '{stripped}'")
                return stripped
            else:
                if DEBUG:
                    print(
                        f"[strip_prefix] No known prefix found in '{model_name}'. Using as is."
                    )
                return model_name
        except Exception as e:
            if DEBUG:
                print(f"[strip_prefix] Error stripping prefix: {e}")
            return model_name  # Return original if stripping fails
        finally:
            if DEBUG:
                print("[strip_prefix] Completed prefix stripping.")

    def pipes(self) -> List[dict]:
        """Register all available Google models."""
        try:
            models = self.get_google_models()
            if DEBUG:
                print(f"[pipes] Registered models: {models}")
            return models
        except Exception as e:
            if DEBUG:
                print(f"[pipes] Error in pipes method: {e}")
            return []
        finally:
            if DEBUG:
                print("[pipes] Completed pipes method.")

    async def pipe(
        self, body: dict, __event_emitter__: Callable[[dict], Awaitable[None]] = None
    ) -> Union[str, Iterator[str]]:
        """Main pipe method to process incoming requests."""
        try:
            if not self.valves.GOOGLE_API_KEY:
                if DEBUG:
                    print("[pipe] GOOGLE_API_KEY is not set.")
                return "Error: GOOGLE_API_KEY is not set"
            try:
                genai.configure(api_key=self.valves.GOOGLE_API_KEY)
                if DEBUG:
                    print("[pipe] Configured Google Generative AI with API key.")
            except Exception as e:
                if DEBUG:
                    print(f"[pipe] Error configuring Google Generative AI: {e}")
                return f"Error configuring Google Generative AI: {e}"

            model_id = body.get("model", "")
            if DEBUG:
                print(f"[pipe] Received model ID: '{model_id}'")

            # Original prefix stripping logic
            try:
                if model_id.startswith("google_genai."):
                    model_id = model_id[12:]
                    if DEBUG:
                        print(f"[pipe] Stripped 'google_genai.': '{model_id}'")
                model_id = model_id.lstrip(".")
                if DEBUG:
                    print(f"[pipe] Stripped leading dots: '{model_id}'")
            except Exception as e:
                if DEBUG:
                    print(f"[pipe] Error processing model ID: {e}")
                return f"Error processing model ID: {e}"

            if not model_id.startswith("gemini-"):
                if DEBUG:
                    print(f"[pipe] Invalid model name format: '{model_id}'")
                return f"Error: Invalid model name format: {model_id}"

            messages = body.get("messages", [])
            stream = body.get("stream", False)

            if DEBUG:
                print(f"[pipe] Incoming messages: {messages}")
                print(f"[pipe] Stream mode: {stream}")

            # Extract system message if present
            system_message = next(
                (msg["content"] for msg in messages if msg.get("role") == "system"),
                None,
            )
            if DEBUG and system_message:
                print(f"[pipe] Extracted system message: '{system_message}'")

            contents = []
            try:
                for message in messages:
                    if message.get("role") != "system":
                        content = message.get("content", "")
                        if isinstance(content, list):
                            parts = []
                            for item in content:
                                if item.get("type") == "text":
                                    parts.append({"text": item.get("text", "")})
                                elif item.get("type") == "image_url":
                                    image_url = item.get("image_url", {}).get("url", "")
                                    if image_url.startswith("data:image"):
                                        image_data = (
                                            image_url.split(",", 1)[1]
                                            if "," in image_url
                                            else ""
                                        )
                                        parts.append(
                                            {
                                                "inline_data": {
                                                    "mime_type": "image/jpeg",
                                                    "data": image_data,
                                                }
                                            }
                                        )
                                    else:
                                        parts.append({"image_url": image_url})
                            contents.append(
                                {"role": message.get("role"), "parts": parts}
                            )
                        else:
                            role = "user" if message.get("role") == "user" else "model"
                            contents.append(
                                {
                                    "role": role,
                                    "parts": [{"text": content}],
                                }
                            )
                if DEBUG:
                    print(f"[pipe] Processed contents: {contents}")
            except Exception as e:
                if DEBUG:
                    print(f"[pipe] Error processing messages: {e}")
                return f"Error processing messages: {e}"

            # Insert system message at the beginning if present
            if system_message:
                try:
                    contents.insert(
                        0,
                        {
                            "role": "user",
                            "parts": [{"text": f"System: {system_message}"}],
                        },
                    )
                    if DEBUG:
                        print("[pipe] Inserted system message into contents.")
                except Exception as e:
                    if DEBUG:
                        print(f"[pipe] Error inserting system message: {e}")
                    return f"Error inserting system message: {e}"

            try:
                client = genai.GenerativeModel(model_name=model_id)
                if DEBUG:
                    print(
                        f"[pipe] Initialized GenerativeModel with model ID: '{model_id}'"
                    )
            except Exception as e:
                if DEBUG:
                    print(f"[pipe] Error initializing GenerativeModel: {e}")
                return f"Error initializing GenerativeModel: {e}"

            generation_config = GenerationConfig(
                temperature=body.get("temperature", 0.7),
                top_p=body.get("top_p", 0.9),
                top_k=body.get("top_k", 40),
                max_output_tokens=body.get("max_tokens", 8192),
                stop_sequences=body.get("stop", []),
            )

            try:
                if self.valves.USE_PERMISSIVE_SAFETY:
                    safety_settings = {
                        genai.types.HarmCategory.HARM_CATEGORY_HARASSMENT: genai.types.HarmBlockThreshold.BLOCK_NONE,
                        genai.types.HarmCategory.HARM_CATEGORY_HATE_SPEECH: genai.types.HarmBlockThreshold.BLOCK_NONE,
                        genai.types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: genai.types.HarmBlockThreshold.BLOCK_NONE,
                        genai.types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: genai.types.HarmBlockThreshold.BLOCK_NONE,
                    }
                    if DEBUG:
                        print("[pipe] Using permissive safety settings.")
                else:
                    safety_settings = body.get("safety_settings", {})
                    if DEBUG:
                        print("[pipe] Using custom safety settings.")
            except Exception as e:
                if DEBUG:
                    print(f"[pipe] Error setting safety settings: {e}")
                return f"Error setting safety settings: {e}"

            if DEBUG:
                print("Google API request details:")
                print("  Model:", model_id)
                print("  Contents:", contents)
                print("  Generation Config:", generation_config)
                print("  Safety Settings:", safety_settings)
                print("  Stream:", stream)

            # Initialize timer variables
            thinking_timer_task = None
            start_time = None

            async def thinking_timer():
                """Asynchronous task to emit periodic status updates."""
                elapsed = 0
                try:
                    while True:
                        await asyncio.sleep(self.valves.emit_interval)
                        elapsed += self.valves.emit_interval
                        # Format elapsed time
                        if elapsed < 60:
                            time_str = f"{elapsed}s"
                        else:
                            minutes, seconds = divmod(elapsed, 60)
                            time_str = f"{minutes}m {seconds}s"
                        status_message = f"Thinking... ({time_str} elapsed)"
                        await emit_status(__event_emitter__, status_message, done=False)
                except asyncio.CancelledError:
                    if DEBUG:
                        print("[thinking_timer] Timer task cancelled.")
                except Exception as e:
                    if DEBUG:
                        print(f"[thinking_timer] Error in timer task: {e}")

            async def emit_status(event_emitter, message, done):
                """Emit status updates asynchronously."""
                try:
                    if event_emitter:
                        status_event = {
                            "type": "status",
                            "data": {"description": message, "done": done},
                        }
                        if asyncio.iscoroutinefunction(event_emitter):
                            await event_emitter(status_event)
                        else:
                            # If the emitter is synchronous, run it in the event loop
                            loop = asyncio.get_event_loop()
                            loop.call_soon_threadsafe(event_emitter, status_event)
                        if DEBUG:
                            print(
                                f"[emit_status] Emitted status: '{message}', done={done}"
                            )
                except Exception as e:
                    if DEBUG:
                        print(f"[emit_status] Error emitting status: {e}")
                finally:
                    if DEBUG:
                        print("[emit_status] Finished emitting status.")

            if self.is_thinking_model(model_id):
                try:
                    # Emit initial 'Thinking' status
                    if __event_emitter__:
                        await emit_status(__event_emitter__, "Thinking...", done=False)

                    # Record the start time
                    start_time = time.time()

                    # Start the thinking timer
                    thinking_timer_task = asyncio.create_task(thinking_timer())

                    # Define a helper function to call generate_content
                    def generate_content_sync(
                        client, contents, generation_config, safety_settings
                    ):
                        return client.generate_content(
                            contents,
                            generation_config=generation_config,
                            safety_settings=safety_settings,
                        )

                    # Execute generate_content asynchronously to prevent blocking
                    loop = asyncio.get_event_loop()
                    response = await loop.run_in_executor(
                        None,
                        generate_content_sync,
                        client,
                        contents,
                        generation_config,
                        safety_settings,
                    )

                    # Process response
                    if len(response.candidates[0].content.parts) > 1:
                        thoughts = response.candidates[0].content.parts[0].text
                        answer = response.candidates[0].content.parts[1].text

                        if __event_emitter__:
                            await self.emit_thoughts(thoughts, __event_emitter__)
                        result = answer
                    else:
                        result = response.candidates[0].content.parts[0].text

                    return result

                except Exception as e:
                    if DEBUG:
                        print(f"[pipe] Error during thinking model processing: {e}")
                    return f"Error: {e}"

                finally:
                    # Calculate total elapsed time
                    if start_time:
                        total_elapsed = int(time.time() - start_time)
                        if total_elapsed < 60:
                            total_time_str = f"{total_elapsed}s"
                        else:
                            minutes, seconds = divmod(total_elapsed, 60)
                            total_time_str = f"{minutes}m {seconds}s"

                        # Cancel the timer task
                        if thinking_timer_task:
                            thinking_timer_task.cancel()
                            try:
                                await thinking_timer_task
                            except asyncio.CancelledError:
                                if DEBUG:
                                    print("[pipe] Timer task successfully cancelled.")
                            except Exception as e:
                                if DEBUG:
                                    print(f"[pipe] Error cancelling timer task: {e}")

                        # Emit final status message
                        final_status = f"Thinking completed in {total_time_str}."
                        await emit_status(__event_emitter__, final_status, done=True)

            # For non-thinking models or streaming
            else:
                if stream:

                    def stream_generator():
                        """Synchronous generator for streaming responses."""
                        try:
                            response = client.generate_content(
                                contents,
                                generation_config=generation_config,
                                safety_settings=safety_settings,
                                stream=True,
                            )
                            for chunk in response:
                                if chunk.text:
                                    yield chunk.text
                        except Exception as e:
                            if DEBUG:
                                print(f"[stream_generator] Error during streaming: {e}")
                            yield f"Error: {e}"
                        finally:
                            if DEBUG:
                                print("[stream_generator] Stream generator completed.")

                    return stream_generator()
                else:
                    try:
                        response = client.generate_content(
                            contents,
                            generation_config=generation_config,
                            safety_settings=safety_settings,
                            stream=False,
                        )
                        if DEBUG:
                            print(f"[pipe] Received response: {response.text}")
                        return response.text
                    except Exception as e:
                        if DEBUG:
                            print(
                                f"[pipe] Error during non-thinking model processing: {e}"
                            )
                        return f"Error: {e}"
            # No need for a finally block here as all exceptions are handled
        finally:
            pass
