<script lang="ts">
    import Showcase from "./lib/views/Showcase.svelte";
    import TryADay from "./lib/views/TryADay.svelte";

    type Tab = "showcase" | "try";
    let tab = $state<Tab>(location.hash === "#try" ? "try" : "showcase");

    function select(next: Tab) {
        tab = next;
        history.replaceState(null, "", next === "try" ? "#try" : "#model");
    }
</script>

<div class="mx-auto max-w-6xl px-4 py-6 sm:px-6 sm:py-10">
    <header class="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
            <h1 class="text-2xl font-semibold tracking-tight">
                Settle <span class="font-normal text-ink-3">· sleep model</span>
            </h1>
            <p class="mt-1 max-w-2xl text-sm text-ink-2">
                A two-process sleep-pressure model for babies aged 0–24 months: sleep pressure builds while
                awake and drains during sleep, and a developing body clock shapes when sleep comes.
            </p>
        </div>
        <nav class="flex rounded-lg border border-line bg-surface-1 p-1 text-sm" aria-label="Views">
            {#each [["showcase", "The model"], ["try", "Try a day"]] as [id, label] (id)}
                <button
                    type="button"
                    class="rounded-md px-3 py-1.5 {tab === id
                        ? 'bg-surface-0 font-semibold text-ink'
                        : 'text-ink-2'}"
                    aria-current={tab === id ? "page" : undefined}
                    onclick={() => select(id as Tab)}>{label}</button
                >
            {/each}
        </nav>
    </header>

    <main>
        {#if tab === "showcase"}
            <Showcase />
        {:else}
            <TryADay />
        {/if}
    </main>

    <footer class="mt-10 border-t border-line pt-4 text-xs text-ink-3">
        Not medical advice. Settle gives general sleep-timing estimates from a mathematical model and does not
        diagnose anything. Nothing you enter is stored. ·
        <a class="underline" href="https://github.com/oaaler/Settle/blob/main/docs/research/sleep-science.md"
            >The science</a
        >
    </footer>
</div>
