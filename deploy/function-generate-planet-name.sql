-- Deploy structs-pg:function-generate-planet-name to pg

BEGIN;

    CREATE OR REPLACE FUNCTION structs.generate_planet_name(target_base_name_length INTEGER DEFAULT 5)
        RETURNS TEXT AS $$
    DECLARE
        -- Constants for letter types
        VOWEL CONSTANT TEXT := 'VOWEL';
        CONSONANT CONSTANT TEXT := 'CONSONANT';

        -- Arrays for vowels and consonants
        vowels TEXT[] := ARRAY['a', 'e', 'i', 'o', 'u', 'y'];
        consonants TEXT[] := ARRAY['b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'p', 'q', 'r', 's', 't', 'v', 'w', 'x', 'y', 'z'];

        -- Bigram arrays
        starting_consonant_bigrams TEXT[] := ARRAY['br', 'ch', 'cl', 'cr', 'fr', 'gr', 'kn', 'll', 'ly', 'pl', 'pr', 'st', 'th', 'tr', 'ts', 'wh'];
        ending_consonant_bigrams TEXT[] := ARRAY['ch', 'ck', 'ct', 'ld', 'll', 'ly', 'nc', 'nd', 'ng', 'ns', 'nt', 'rd', 'rs', 'rt', 'ss', 'st', 'th', 'ts', 'wn'];

        -- Greek letters
        greek_letters TEXT[] := ARRAY['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon', 'Zeta', 'Eta', 'Theta', 'Iota', 'Kappa', 'Lambda', 'Mu', 'Nu', 'Xi', 'Omicron', 'Pi', 'Rho', 'Sigma', 'Tau', 'Upsilon', 'Phi', 'Chi', 'Psi', 'Omega'];

        -- Roman numerals
        roman_numerals TEXT[] := ARRAY['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

        -- Common prefixes and suffixes
        common_prefixes TEXT[] := ARRAY['Nega', 'New', 'Proxima'];
        common_suffix TEXT[] := ARRAY['Major', 'Minor', 'Prime'];

        -- Flair probabilities
        punctuation_mark_prob CONSTANT NUMERIC := 0.25;
        common_prefix_prob CONSTANT NUMERIC := 0.0625;
        common_suffix_prob CONSTANT NUMERIC := 0.0625;
        roman_numeral_prob CONSTANT NUMERIC := 0.125;
        greek_letter_prob CONSTANT NUMERIC := 0.25;

        -- Variables for name generation
        length_remaining INTEGER;
        last_letter_type TEXT := '';
        name TEXT := '';
        name_lower TEXT := '';
        possible_ngrams TEXT[] := '{}';
        selected_ngram TEXT;
        random_val NUMERIC;

        is_banned BOOLEAN := FALSE;
        generate BOOLEAN := TRUE;
        insert_pos INTEGER;

    BEGIN

        -- Main generation loop
        WHILE generate LOOP
                -- Reset for new generation
                length_remaining := target_base_name_length;
                last_letter_type := '';
                name := '';

                -- Generate base name
                WHILE length_remaining > 0 LOOP
                        possible_ngrams := '{}';

                        -- Add vowels
                        IF length_remaining = target_base_name_length OR last_letter_type = CONSONANT THEN
                            possible_ngrams := array_append(possible_ngrams, vowels[1 + floor(random() * array_length(vowels, 1))::INTEGER]);
                        END IF;

                        -- Add consonants
                        IF length_remaining = target_base_name_length OR last_letter_type = VOWEL THEN
                            possible_ngrams := array_append(possible_ngrams, consonants[1 + floor(random() * array_length(consonants, 1))::INTEGER]);
                        END IF;

                        -- Add starting consonant bigrams
                        IF length_remaining > 2 AND length_remaining = target_base_name_length THEN
                            possible_ngrams := array_append(possible_ngrams, starting_consonant_bigrams[1 + floor(random() * array_length(starting_consonant_bigrams, 1))::INTEGER]);
                        END IF;

                        -- Add middle consonant bigrams
                        IF length_remaining > 2 AND length_remaining != target_base_name_length AND last_letter_type = VOWEL THEN
                            possible_ngrams := array_append(possible_ngrams, (starting_consonant_bigrams || ending_consonant_bigrams)[1 + floor(random() * array_length(starting_consonant_bigrams || ending_consonant_bigrams, 1))::INTEGER]);
                        END IF;

                        -- Add ending consonant bigrams
                        IF length_remaining = 2 AND last_letter_type = VOWEL THEN
                            possible_ngrams := array_append(possible_ngrams, (starting_consonant_bigrams || ending_consonant_bigrams)[1 + floor(random() * array_length(starting_consonant_bigrams || ending_consonant_bigrams, 1))::INTEGER]);
                        END IF;

                        -- Add bigrams starting with vowel
                        IF length_remaining > 1 AND (length_remaining = target_base_name_length OR last_letter_type = CONSONANT) THEN
                            selected_ngram := vowels[1 + floor(random() * (array_length(vowels, 1) - 1))::INTEGER] || consonants[1 + floor(random() * array_length(consonants, 1))::INTEGER];
                            possible_ngrams := array_append(possible_ngrams, selected_ngram);
                        END IF;

                        -- Add bigrams ending with vowel
                        IF length_remaining > 1 AND (length_remaining = target_base_name_length OR last_letter_type = VOWEL) THEN
                            selected_ngram := consonants[1 + floor(random() * array_length(consonants, 1))::INTEGER] || vowels[1 + floor(random() * array_length(vowels, 1))::INTEGER];
                            possible_ngrams := array_append(possible_ngrams, selected_ngram);
                        END IF;

                        -- Select random ngram
                        IF array_length(possible_ngrams, 1) > 0 THEN
                            selected_ngram := possible_ngrams[1 + floor(random() * array_length(possible_ngrams, 1))::INTEGER];
                            name := name || selected_ngram;

                            -- Capitalize first letter if it's the start
                            IF target_base_name_length = length_remaining THEN
                                name := upper(substring(name from 1 for 1)) || substring(name from 2);
                            END IF;

                            -- Determine last letter type
                            IF length(name) > 0 THEN
                                IF array_position(vowels, lower(substring(name from length(name) for 1))) IS NOT NULL THEN
                                    last_letter_type := VOWEL;
                                ELSE
                                    last_letter_type := CONSONANT;
                                END IF;
                            END IF;

                            length_remaining := target_base_name_length - length(name);
                        END IF;
                    END LOOP;

                -- Add punctuation mark
                IF target_base_name_length >= 5 AND random() < punctuation_mark_prob THEN
                    random_val := random();
                    IF random_val < 0.5 THEN
                        -- Insert apostrophe
                        insert_pos := 1 + floor(random() * 2)::INTEGER;
                        name := substring(name from 1 for insert_pos) || '''' || substring(name from insert_pos + 1);
                    ELSE
                        -- Insert hyphen
                        insert_pos := 2 + floor(random() * (length(name)/2 - 1))::INTEGER;
                        name := substring(name from 1 for insert_pos) || '-' || substring(name from insert_pos + 1);
                    END IF;
                END IF;

                name_lower := lower(name);
                IF EXISTS (SELECT FROM structs.banned_word
                            WHERE
                                name_lower LIKE '%' || banned_word.value || '%'
                                OR
                                regexp_replace(name_lower, '[^a-zA-Z]', '', 'g') LIKE '%' || banned_word.value|| '%'
                                OR EXISTS (
                                    SELECT 1
                                    FROM unnest(string_to_array(name_lower, ' ')) AS word_part
                                    WHERE word_part LIKE '%' || banned_word.value || '%'
                                       OR regexp_replace(word_part, '[^a-zA-Z]', '', 'g') LIKE '%' || banned_word.value || '%'
                                )
                                OR EXISTS (
                                    SELECT 1
                                    FROM unnest(string_to_array(name_lower, '-')) AS word_part
                                    WHERE word_part LIKE '%' || banned_word.value || '%'
                                       OR regexp_replace(word_part, '[^a-zA-Z]', '', 'g') LIKE '%' || banned_word.value || '%'
                                )
                ) THEN
                    is_banned := TRUE;
                END IF;

                -- If not banned, we can use this name
                IF NOT is_banned THEN
                    generate := FALSE;
                END IF;
            END LOOP;

        -- Add flair elements
        -- Common prefix
        IF random() < common_prefix_prob THEN
            name := common_prefixes[1 + floor(random() * array_length(common_prefixes, 1))::INTEGER] || ' ' || name;
        END IF;

        -- Greek letter
        IF random() < greek_letter_prob THEN
            name := name || ' ' || greek_letters[1 + floor(random() * array_length(greek_letters, 1))::INTEGER];
        END IF;

        -- Common suffix
        IF random() < common_suffix_prob THEN
            name := name || ' ' || common_suffix[1 + floor(random() * array_length(common_suffix, 1))::INTEGER];
        END IF;

        -- Roman numeral
        IF random() < roman_numeral_prob THEN
            name := name || ' ' || roman_numerals[1 + floor(random() * array_length(roman_numerals, 1))::INTEGER];
        END IF;

        RETURN name;
    END;
    $$ LANGUAGE plpgsql;

COMMIT;



